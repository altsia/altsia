///|
pub type Prelude

///|
pub enum PreludeChildFlow {
  InlineChildren
  MixedChildren
}

///|
fn CallContext::compile_prelude_element(
  self : CallContext,
) -> Result[ElementOutput?, Diagnostic] {
  let { call, context } = self
  let f = (output : ElementOutput) => Some(output)
  match call.tag {
    "_" => (context.compile_inline)(call.children).map(f)
    "h" => self.compile_hspace().map(f)
    "list" => self.compile_alias("ul", InlineChildren).map(f)
    "enum" => self.compile_alias("ol", InlineChildren).map(f)
    "item" => self.compile_alias("li", MixedChildren).map(f)
    "fig" => self.compile_alias("figure", InlineChildren).map(f)
    "block" => self.compile_alias("div", MixedChildren).map(f)
    "slot" => self.compile_slot().map(f)
    "codeblock" => self.compile_code().map(f)
    "section" => self.compile_section().map(f)
    "note" | "warning" | "tip" => self.compile_admonition(call.tag).map(f)
    _ if builtin_languages.contains(call.tag) =>
      self.compile_language_span(normalize_bcp47(call.tag)).map(f)
    _ => Ok(None)
  }
}

///|
fn Prelude::is_block(tag : String) -> Bool? {
  match tag {
    "_" | "h" => Some(false)
    "section"
    | "list"
    | "enum"
    | "item"
    | "fig"
    | "block"
    | "note"
    | "warning"
    | "tip"
    | "codeblock"
    | "slot" => Some(true)
    _ => None
  }
}

///|
fn CallContext::compile_alias(
  self : CallContext,
  tag : String,
  flow : PreludeChildFlow,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    let children = match flow {
      InlineChildren => (context.compile_inline)(call.children)
      MixedChildren => (context.compile_mixed)(call.children)
    }
    children.map(output => {
      body: [HtmlNode::Element(tag, html_attrs, output.body)],
      head: output.head,
    })
  })
}

///|
fn CallContext::compile_language_span(
  self : CallContext,
  language_tag : String,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    (context.compile_inline)(call.children).map(output => {
      html_attrs.push(("lang", Some(language_tag)))
      {
        body: [HtmlNode::Element("span", html_attrs, output.body)],
        head: output.head,
      }
    })
  })
}

///|
fn CallContext::compile_section(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  let html_attrs : Array[(String, String?)] = []
  let section_children : Array[HtmlNode] = []
  let mut title : String? = None
  for attr in call.attrs {
    if attr.name == "title" {
      if attr.value is Some(value) {
        match value_to_scalar(value, context.env) {
          Ok(text) => title = Some(text)
          Err(error) => return Err(error)
        }
      }
    } else {
      match compile_attr_value(attr.value, context.env) {
        Ok(compiled) => html_attrs.push((attr.name, compiled))
        Err(error) => return Err(error)
      }
    }
  }
  if title is Some(text) {
    let level = clamp_heading_level(context.current_heading_level)
    section_children.push(
      HtmlNode::Element("h" + level.to_string(), [], [HtmlNode::Text(text)]),
    )
  }
  (context.compile_block_at)(call.children, context.current_heading_level + 1).map(output => {
      section_children.append(output.body)
      {
        body: [HtmlNode::Element("section", html_attrs, section_children)],
        head: output.head,
      }
    },
  )
}

///|
fn CallContext::compile_admonition(
  self : CallContext,
  kind : String,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    @sexp.HtmlAttrs(html_attrs).append_class(kind)
    (context.compile_block)(call.children).map(output => {
      body: [HtmlNode::Element("aside", html_attrs, output.body)],
      head: output.head,
    })
  })
}

///|
fn CallContext::compile_code(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    let lang = html_attrs.iter().find_first(a => a.0 == "lang").bind(a => a.1)
    (context.compile_text_only)(call.children).map(source => {
      let code_attrs : Array[(String, String?)] = []
      if lang is Some(value) {
        code_attrs.push(("class", Some("lang-" + value)))
      }
      body_output([
        HtmlNode::Element("pre", [], [
          HtmlNode::Element("code", code_attrs, [HtmlNode::Text(source)]),
        ]),
      ])
    })
  })
}

///|
fn CallContext::compile_slot(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    (context.compile_text_only)(call.children).map(source => {
      body_output([
        HtmlNode::Element("pre", html_attrs, [HtmlNode::Text(source)]),
      ])
    })
  })
}

///|
fn CallContext::compile_hspace(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  guard call.attrs.is_empty() else {
    return Err(
      call.span.diagnostic(
        DiagnosticPhase::Type,
        "(h ...) does not accept attributes",
      ),
    )
  }
  guard !call.children.is_empty() else {
    return Err(
      call.span.diagnostic(DiagnosticPhase::Type, "(h ...) requires a length"),
    )
  }

  (context.compile_text_only)(call.children).bind(length => {
    let length = length.trim()
    let html = HtmlNode::Element(
      "span",
      [
        ("aria-hidden", Some("true")),
        (
          "style",
          Some(
            "display: inline-block; width: \{length}; height: 0; vertical-align: baseline",
          ),
        ),
      ],
      [],
    )
    Ok(body_output([html]))
  })
}
