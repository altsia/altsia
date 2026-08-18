///|
pub enum PreludeChildFlow {
  InlineChildren
  MixedChildren
}

///|
priv struct SectionElement {
  html_attrs : @sexp.Attrs
  title : String?
  children : Array[Node]
}

///|
fn CallContext::compile_prelude_element(
  self : CallContext,
) -> ElementOutput? raise Diagnostic {
  let { call, context } = self
  match call.tag {
    "_" => Some((context.compile_inline)(call.children))
    "h" => Some(self.compile_hspace())
    "lorem" => Some(self.compile_lorem())
    "list" => Some(self.compile_alias("ul", InlineChildren))
    "enum" => Some(self.compile_alias("ol", InlineChildren))
    "item" => Some(self.compile_alias("li", MixedChildren))
    "fig" => Some(self.compile_alias("figure", InlineChildren))
    "block" => Some(self.compile_alias("div", MixedChildren))
    "slot" => Some(self.compile_slot())
    "codeblock" => Some(self.compile_code())
    "section" => Some(self.compile_section())
    "note" | "warning" | "tip" => Some(self.compile_admonition(call.tag))
    _ if @i18n.builtin_languages.contains(call.tag) =>
      Some(
        self.compile_language_span(@i18n.normalize_builtin_language(call.tag)),
      )
    _ => None
  }
}

///|
fn CallContext::compile_alias(
  self : CallContext,
  tag : String,
  flow : PreludeChildFlow,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let html_attrs = compile_attrs(call.attrs, context.env)
  let output = match flow {
    InlineChildren => (context.compile_inline)(call.children)
    MixedChildren => (context.compile_mixed)(call.children)
  }
  {
    body: [HtmlNode::Element(tag, html_attrs, output.body)],
    head: output.head,
    inline_body: false,
  }
}

///|
fn CallContext::compile_language_span(
  self : CallContext,
  language_tag : String,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let html_attrs = compile_attrs(call.attrs, context.env)
  let output = (context.compile_inline)(call.children)
  html_attrs.upsert("lang", Some(language_tag))
  {
    body: [HtmlNode::Element("span", html_attrs, output.body)],
    head: output.head,
    inline_body: true,
  }
}

///|
fn CallContext::compile_section(
  self : CallContext,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let section = SectionElement::from_call(call, context.env)
  let output = (context.compile_block_at)(
    section.children,
    context.current_heading_level + 1,
  )
  let section_children = section.heading_nodes(context.current_heading_level)
  section_children.append(output.body)
  section.to_output(section_children, output.head)
}

///|
fn SectionElement::from_call(
  call : ElementCall,
  env : CompileEnv,
) -> SectionElement raise Diagnostic {
  let html_attrs = @sexp.Attrs(Map([]))
  let mut title : String? = None
  for attr in call.attrs {
    match attr.name {
      "title" =>
        if attr.value is Some(value) {
          title = Some(value.to_scalar(env))
        }
      _ => html_attrs.upsert(attr.name, compile_optional_attr_scalar(attr, env))
    }
  }
  { html_attrs, title, children: call.children }
}

///|
fn SectionElement::heading_nodes(
  self : SectionElement,
  current_heading_level : Int,
) -> Array[HtmlNode] {
  match self.title {
    Some(text) => {
      let level = clamp_heading_level(current_heading_level)
      [
        HtmlNode::Element("h" + level.to_string(), @sexp.Attrs(Map([])), [
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
fn clamp_heading_level(level : Int) -> Int {
  level.clamp(min=1, max=6)
}

///|
fn CallContext::compile_admonition(
  self : CallContext,
  kind : String,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let html_attrs = compile_attrs(call.attrs, context.env)
  html_attrs.append_class(kind)
  let output = (context.compile_block)(call.children)
  {
    body: [HtmlNode::Element("aside", html_attrs, output.body)],
    head: output.head,
    inline_body: false,
  }
}

///|
fn CallContext::compile_code(
  self : CallContext,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let html_attrs = compile_attrs(call.attrs, context.env)
  let lang = html_attrs.0.get("lang").bind(value => value)
  let source = (context.compile_text_only)(call.children)
  let code_attrs = @sexp.Attrs(Map([]))
  if lang is Some(value) {
    code_attrs.upsert("class", Some("lang-" + value))
  }
  ElementOutput::flow([
    HtmlNode::Element("pre", @sexp.Attrs(Map([])), [
      HtmlNode::Element("code", code_attrs, [HtmlNode::Text(source)]),
    ]),
  ])
}

///|
fn CallContext::compile_slot(
  self : CallContext,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  let html_attrs = compile_attrs(call.attrs, context.env)
  let source = (context.compile_text_only)(call.children)
  ElementOutput::flow([
    HtmlNode::Element("pre", html_attrs, [HtmlNode::Text(source)]),
  ])
}

///|
fn CallContext::compile_hspace(
  self : CallContext,
) -> ElementOutput raise Diagnostic {
  let { call, context } = self
  guard call.attrs.is_empty() else {
    raise call.span.diagnostic(
      DiagnosticPhase::Type,
      "(h ...) does not accept attributes",
    )
  }
  guard !call.children.is_empty() else {
    raise call.span.diagnostic(
      DiagnosticPhase::Type,
      "(h ...) requires a length",
    )
  }

  let length = (context.compile_text_only)(call.children).trim()
  let html = HtmlNode::Element(
    "span",
    @sexp.Attrs({
      "aria-hidden": Some("true"),
      "style": Some(
        "display: inline-block; width: \{length}; height: 0; vertical-align: baseline",
      ),
    }),
    [],
  )
  ElementOutput::body([html])
}
