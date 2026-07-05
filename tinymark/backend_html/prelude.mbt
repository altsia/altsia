///|
pub enum PreludeChildFlow {
  InlineChildren
  MixedChildren
}

///|
priv struct SectionElement {
  html_attrs : @sexp.HtmlAttrs
  title : String?
  children : Array[Node]
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
    "lorem" => self.compile_lorem().map(f)
    "list" => self.compile_alias("ul", InlineChildren).map(f)
    "enum" => self.compile_alias("ol", InlineChildren).map(f)
    "item" => self.compile_alias("li", MixedChildren).map(f)
    "fig" => self.compile_alias("figure", InlineChildren).map(f)
    "block" => self.compile_alias("div", MixedChildren).map(f)
    "slot" => self.compile_slot().map(f)
    "codeblock" => self.compile_code().map(f)
    "section" => self.compile_section().map(f)
    "note" | "warning" | "tip" => self.compile_admonition(call.tag).map(f)
    _ if @i18n.builtin_languages.contains(call.tag) =>
      self.compile_language_span(@i18n.normalize_builtin_language(call.tag)).map(f)
    _ => Ok(None)
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
      inline_body: false,
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
      html_attrs.upsert("lang", Some(language_tag))
      {
        body: [HtmlNode::Element("span", html_attrs, output.body)],
        head: output.head,
        inline_body: true,
      }
    })
  })
}

///|
fn CallContext::compile_section(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  let section = match SectionElement::from_call(call, context.env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  (context.compile_block_at)(
    section.children,
    context.current_heading_level + 1,
  ).map(output => {
    let section_children = section.heading_nodes(context.current_heading_level)
    section_children.append(output.body)
    section.to_output(section_children, output.head)
  })
}

///|
fn SectionElement::from_call(
  call : ElementCall,
  env : CompileEnv,
) -> Result[SectionElement, Diagnostic] {
  let html_attrs = @sexp.HtmlAttrs({})
  let mut title : String? = None
  for attr in call.attrs {
    match attr.name {
      "title" =>
        if attr.value is Some(value) {
          match value.to_scalar(env) {
            Ok(text) => title = Some(text)
            Err(error) => return Err(error)
          }
        }
      _ =>
        match attr.optional_scalar(env) {
          Ok(compiled) => html_attrs.upsert(attr.name, compiled)
          Err(error) => return Err(error)
        }
    }
  }
  Ok({ html_attrs, title, children: call.children })
}

///|
fn SectionElement::heading_nodes(
  self : SectionElement,
  current_heading_level : Int,
) -> Array[HtmlNode] {
  match self.title {
    Some(text) => {
      let level = @core.clamp_heading_level(current_heading_level)
      [
        HtmlNode::Element("h" + level.to_string(), @sexp.HtmlAttrs({}), [
          HtmlNode::Text(text),
        ]),
      ]
    }
    None => []
  }
}

///|
fn SectionElement::to_output(
  self : SectionElement,
  children : Array[HtmlNode],
  head : Array[HtmlNode],
) -> ElementOutput {
  {
    body: [HtmlNode::Element("section", self.html_attrs, children)],
    head,
    inline_body: false,
  }
}

///|
fn CallContext::compile_admonition(
  self : CallContext,
  kind : String,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    html_attrs.append_class(kind)
    (context.compile_block)(call.children).map(output => {
      body: [HtmlNode::Element("aside", html_attrs, output.body)],
      head: output.head,
      inline_body: false,
    })
  })
}

///|
fn CallContext::compile_code(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    let lang = html_attrs.0.get("lang").bind(value => value)
    (context.compile_text_only)(call.children).map(source => {
      let code_attrs = @sexp.HtmlAttrs({})
      if lang is Some(value) {
        code_attrs.upsert("class", Some("lang-" + value))
      }
      ElementOutput::flow([
        HtmlNode::Element("pre", @sexp.HtmlAttrs({}), [
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
      ElementOutput::flow([
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
      @sexp.HtmlAttrs({
        "aria-hidden": Some("true"),
        "style": Some(
          "display: inline-block; width: \{length}; height: 0; vertical-align: baseline",
        ),
      }),
      [],
    )
    Ok(ElementOutput::body([html]))
  })
}
