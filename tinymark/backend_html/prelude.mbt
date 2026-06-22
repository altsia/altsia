///|
priv enum PreludeChildFlow {
  InlineChildren
  MixedChildren
}

///|
fn compile_prelude_element(
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput?, Diagnostic] {
  match call.tag {
    "_" => (context.compile_inline)(call.children).map(output => Some(output))
    "section" =>
      compile_prelude_section(call, context).map(output => Some(output))
    "list" =>
      compile_prelude_mapped(call, context, "ul", InlineChildren).map(output => {
        Some(output)
      })
    "enum" =>
      compile_prelude_mapped(call, context, "ol", InlineChildren).map(output => {
        Some(output)
      })
    "item" =>
      compile_prelude_mapped(call, context, "li", MixedChildren).map(output => {
        Some(output)
      })
    "fig" =>
      compile_prelude_mapped(call, context, "figure", InlineChildren).map(output => {
        Some(output)
      })
    "block" =>
      compile_prelude_mapped(call, context, "div", MixedChildren).map(output => {
        Some(output)
      })
    "note" | "warning" | "tip" =>
      compile_prelude_admonition(call.tag, call, context).map(output => {
        Some(output)
      })
    "codeblock" =>
      compile_prelude_code(call, context).map(output => Some(output))
    "slot" => compile_prelude_slot(call, context).map(output => Some(output))
    "h" => compile_hspace(call, context).map(output => Some(output))
    _ => Ok(None)
  }
}

///|
fn prelude_block_tag(tag : String) -> Bool? {
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
fn compile_prelude_mapped(
  call : ElementCall,
  context : CompileContext,
  tag : String,
  flow : PreludeChildFlow,
) -> Result[ElementOutput, Diagnostic] {
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
fn compile_prelude_section(
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput, Diagnostic] {
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
fn compile_prelude_admonition(
  kind : String,
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput, Diagnostic] {
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    @sexp.HtmlAttrs(html_attrs).append_class(kind)
    (context.compile_block)(call.children).map(output => {
      body: [HtmlNode::Element("aside", html_attrs, output.body)],
      head: output.head,
    })
  })
}

///|
fn compile_prelude_code(
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput, Diagnostic] {
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
fn compile_prelude_slot(
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput, Diagnostic] {
  compile_attrs(call.attrs, context.env).bind(html_attrs => {
    (context.compile_text_only)(call.children).map(source => {
      body_output([
        HtmlNode::Element("pre", html_attrs, [HtmlNode::Text(source)]),
      ])
    })
  })
}

///|
fn compile_hspace(
  call : ElementCall,
  context : CompileContext,
) -> Result[ElementOutput, Diagnostic] {
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
