///|
type HtmlNode = @sexp.SexpNode

///|
priv enum ContentModel {
  InlineOnly
  BlockFlow
  MixedFlow
}

///|
priv struct CssStyleAttrs {
  html_attrs : @sexp.HtmlAttrs
  scope : String?
}

///|
pub type ElementCall = BackendElementCall

///|
pub type CompileContext = BackendCompileContext[HtmlNode, HtmlNode]

///|
pub type CallContext = BackendCallContext[HtmlNode, HtmlNode]

///|
priv struct ElementCompileInput {
  call : ElementCall
  context : CompileContext
}

///|
pub type ElementOutput = BackendOutput[HtmlNode, HtmlNode]

///|
pub type ElementResolver = BackendElementResolver[HtmlNode, HtmlNode]

///|
pub(all) struct CompileOptions {
  // Heading level for top-level section titles; nested sections increment it.
  initial_heading_level : Int
  // Wrap contiguous inline output in <p> elements when compiling a sequence.
  wrap_inline_content : Bool
  // Element resolvers consulted before built-in HTML element handling.
  extensions : Array[ElementResolver]
}

///|
pub fn CompileOptions::fragment() -> CompileOptions {
  { initial_heading_level: 1, wrap_inline_content: true, extensions: [] }
}

///|
pub fn compile_fragment(
  doc : Document,
  env? : CompileEnv,
  options? : CompileOptions,
) -> Array[HtmlNode] raise Diagnostic {
  let compile_env = env.unwrap_or(CompileEnv::empty())
  let compile_options = options.unwrap_or(CompileOptions::fragment())
  compile_backend_nodes(
    doc.nodes,
    compile_env,
    compile_options.initial_heading_level,
    compile_options.wrap_inline_content,
    html_render_backend(),
    compile_options.extensions,
  )
}

///|
pub fn to_sexp_nodes(source : String) -> Array[HtmlNode] raise Diagnostic {
  compile_fragment(parse(source))
}

///|
pub fn to_html(source : String) -> String raise Diagnostic {
  @sexp.render_html_fragment(to_sexp_nodes(source))
}

///|
pub fn to_html_document(
  source : String,
  options : HtmlDocumentOptions?,
) -> String raise Diagnostic {
  let document_options = options.unwrap_or(HtmlDocumentOptions::default())
  compile_html_document(parse(source), options=document_options)
}

///|
fn html_render_backend() -> RenderBackend[HtmlNode, HtmlNode] {
  {
    text: text => HtmlNode::Text(text),
    interpolate_text: interpolate_scalar,
    append_inline_node: append_paragraph_content_node,
    flush_inline_run: flush_paragraph,
    output_text: node => {
      match node {
        HtmlNode::Text(text) => Some(text)
        _ => None
      }
    },
    resolve_element: html_backend_resolver,
  }
}

///|
fn html_backend_resolver(
  compiler : CallContext,
) -> ElementOutput? raise Diagnostic {
  let call = compiler.call
  if html_head_resolver(compiler) is Some(output) {
    return Some(output)
  }
  if compiler.compile_prelude_element() is Some(output) {
    return Some(output)
  }
  let input = { call, context: compiler.context }
  Some(
    match call.tag {
      "style" => compile_scoped_style(input)
      _ => compile_mapped_element(call.tag, input)
    },
  )
}

///|
fn html_head_resolver(
  compiler : CallContext,
) -> ElementOutput? raise Diagnostic {
  if compiler.call.tag != "html.head" {
    return None
  }
  let output = (compiler.context.compile_inline)(compiler.call.children)
  let head = output.body
  head.append(output.head)
  Some({ body: [], head, inline_body: true })
}

///|
fn compile_mapped_element(
  tag : String,
  input : ElementCompileInput,
) -> ElementOutput raise Diagnostic {
  let html_attrs = compile_attrs(input.call.attrs, input.context.env)
  let output = compile_children_for_tag_output(tag, input)
  let node = HtmlNode::Element(tag, html_attrs, output.body)
  match content_model(tag) {
    InlineOnly => { body: [node], head: output.head, inline_body: true }
    BlockFlow | MixedFlow =>
      { body: [node], head: output.head, inline_body: false }
  }
}

///|
fn compile_children_for_tag_output(
  tag : String,
  input : ElementCompileInput,
) -> ElementOutput raise Diagnostic {
  match content_model(tag) {
    InlineOnly => (input.context.compile_inline)(input.call.children)
    BlockFlow => (input.context.compile_block)(input.call.children)
    MixedFlow => (input.context.compile_mixed)(input.call.children)
  }
}

///|
fn content_model(tag : String) -> ContentModel {
  match tag {
    "blockquote" => ContentModel::BlockFlow
    "li" | "div" => ContentModel::MixedFlow
    _ if is_flow_container_tag(tag) => ContentModel::MixedFlow
    _ if is_custom_block_tag(tag) => ContentModel::MixedFlow
    _ => ContentModel::InlineOnly
  }
}

///|
fn is_flow_container_tag(tag : String) -> Bool {
  match tag {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "details"
    | "dialog"
    | "div"
    | "dl"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hr"
    | "li"
    | "main"
    | "nav"
    | "ol"
    | "p"
    | "pre"
    | "section"
    | "style"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}

///|
fn is_custom_block_tag(tag : String) -> Bool {
  tag.contains(".") || tag.contains("-")
}

///|
fn compile_scoped_style(
  input : ElementCompileInput,
) -> ElementOutput raise Diagnostic {
  let style_attrs = compile_style_attrs(input.call.attrs, input.context.env)
  let rules = CSS::compile_rule_nodes(
    input.call.children,
    style_attrs.scope,
    input.context.env,
  )
  ElementOutput::body([
    HtmlNode::Element("style", style_attrs.html_attrs, [
      HtmlNode::RawHtml(rules.join("")),
    ]),
  ])
}

///|
fn compile_style_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> CssStyleAttrs raise Diagnostic {
  let html_attrs = @sexp.HtmlAttrs(Map([]))
  let mut scope : String? = None
  for attr in attrs {
    if attr.name == "scope" {
      scope = Some(compile_style_scope(attr, env))
      continue
    }
    html_attrs.upsert(attr.name, compile_optional_attr_scalar(attr, env))
  }
  { html_attrs, scope }
}

///|
fn compile_style_scope(
  attr : Attr,
  env : CompileEnv,
) -> String raise Diagnostic {
  guard attr.value is Some(value) else {
    raise attr.span.diagnostic(
      DiagnosticPhase::Type,
      "style scope requires a value",
    )
  }
  let text = value.to_scalar(env)
  guard !text.trim().is_empty() else {
    raise attr.span.diagnostic(
      DiagnosticPhase::Type,
      "style scope cannot be empty",
    )
  }
  CSS::normalize_css_scope(text)
}

///|
fn compile_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> @sexp.HtmlAttrs raise Diagnostic {
  let html_attrs = @sexp.HtmlAttrs(Map([]))
  for attr in attrs {
    html_attrs.upsert(attr.name, compile_optional_attr_scalar(attr, env))
  }
  html_attrs
}

///|
fn compile_optional_attr_scalar(
  attr : Attr,
  env : CompileEnv,
) -> String? raise Diagnostic {
  match attr.value {
    Some(value) => Some(value.to_scalar(env))
    None => None
  }
}

///|
fn required_attr_scalar(
  attr : Attr,
  env : CompileEnv,
  missing_message : String,
) -> String raise Diagnostic {
  guard attr.value is Some(value) else {
    raise attr.span.diagnostic(DiagnosticPhase::Type, missing_message)
  }
  value.to_scalar(env)
}

///|
fn flag_attr_bool(attr : Attr, message : String) -> Bool raise Diagnostic {
  match attr.value {
    Some(value) => value.to_bool(attr.span, message)
    None => true
  }
}
