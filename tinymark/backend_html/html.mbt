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
) -> Result[Array[HtmlNode], Diagnostic] {
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
pub fn to_sexp_nodes(source : String) -> Result[Array[HtmlNode], Diagnostic] {
  parse(source).bind(doc => compile_fragment(doc))
}

///|
pub fn to_html(source : String) -> Result[String, Diagnostic] {
  to_sexp_nodes(source).map(nodes => @sexp.render_html_fragment(nodes))
}

///|
pub fn to_html_document(
  source : String,
  options : HtmlDocumentOptions?,
) -> Result[String, Diagnostic] {
  let document_options = options.unwrap_or(HtmlDocumentOptions::default())
  parse(source).bind(doc => compile_html_document(doc, options=document_options))
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
) -> Result[ElementOutput?, Diagnostic] {
  let call = compiler.call
  match html_head_resolver(compiler) {
    Ok(Some(output)) => return Ok(Some(output))
    Err(error) => return Err(error)
    _ => ()
  }
  match compiler.compile_prelude_element() {
    Ok(Some(output)) => return Ok(Some(output))
    Err(error) => return Err(error)
    _ => ()
  }
  let input = { call, context: compiler.context }
  let output = match call.tag {
    "style" => compile_scoped_style(input)
    _ => compile_mapped_element(call.tag, input)
  }
  output.map(value => Some(value))
}

///|
fn html_head_resolver(
  compiler : CallContext,
) -> Result[ElementOutput?, Diagnostic] {
  if compiler.call.tag != "html.head" {
    return Ok(None)
  }
  (compiler.context.compile_inline)(compiler.call.children).map(output => {
    let head = output.body
    head.append(output.head)
    Some({ body: [], head, inline_body: true })
  })
}

///|
fn compile_mapped_element(
  tag : String,
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
  compile_attrs(input.call.attrs, input.context.env).bind(html_attrs => {
    compile_children_for_tag_output(tag, input).map(output => {
      let node = HtmlNode::Element(tag, html_attrs, output.body)
      match content_model(tag) {
        InlineOnly => { body: [node], head: output.head, inline_body: true }
        BlockFlow | MixedFlow =>
          { body: [node], head: output.head, inline_body: false }
      }
    })
  })
}

///|
fn compile_children_for_tag_output(
  tag : String,
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
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
) -> Result[ElementOutput, Diagnostic] {
  compile_style_attrs(input.call.attrs, input.context.env).bind(style_attrs => {
    compile_css_rule_nodes(
      input.call.children,
      style_attrs.scope,
      input.context.env,
    ).map(rules => {
      ElementOutput::body([
        HtmlNode::Element("style", style_attrs.html_attrs, [
          HtmlNode::RawHtml(rules.join("")),
        ]),
      ])
    })
  })
}

///|
fn compile_style_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> Result[CssStyleAttrs, Diagnostic] {
  let html_attrs = @sexp.HtmlAttrs({})
  let mut scope : String? = None
  for attr in attrs {
    if attr.name == "scope" {
      match compile_style_scope(attr, env) {
        Ok(value) => scope = Some(value)
        Err(error) => return Err(error)
      }
      continue
    }
    match attr.optional_scalar(env) {
      Ok(compiled) => html_attrs.upsert(attr.name, compiled)
      Err(error) => return Err(error)
    }
  }
  Ok({ html_attrs, scope })
}

///|
fn compile_style_scope(
  attr : Attr,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  guard attr.value is Some(value) else {
    return Err(
      attr.span.diagnostic(
        DiagnosticPhase::Type,
        "style scope requires a value",
      ),
    )
  }
  value
  .to_scalar(env)
  .bind(text => {
    if text.trim().is_empty() {
      Err(
        attr.span.diagnostic(
          DiagnosticPhase::Type,
          "style scope cannot be empty",
        ),
      )
    } else {
      Ok(normalize_css_scope(text))
    }
  })
}

///|
fn compile_css_rule_nodes(
  children : Array[Node],
  scope : String?,
  env : CompileEnv,
) -> Result[Array[String], Diagnostic] {
  let rules : Array[String] = []
  for child in children {
    let result = compile_css_rule_node(child, scope, env)
    if result is Ok(Some(rule)) {
      rules.push(rule)
    }
    if result is Err(error) {
      return Err(error)
    }
  }
  Ok(rules)
}

///|
fn compile_css_rule_node(
  node : Node,
  scope : String?,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  match node {
    Element(tag, attrs, children, span) =>
      compile_css_rule_element(tag, attrs, children, scope, env, span)
    Text(text, _) if text.trim().is_empty() => Ok(None)
    _ =>
      Err(
        node
        .span()
        .diagnostic(
          DiagnosticPhase::ContentModel,
          "style only accepts css rule elements",
        ),
      )
  }
}

///|
fn compile_css_rule_element(
  tag : String,
  attrs : Array[Attr],
  children : Array[Node],
  scope : String?,
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String?, Diagnostic] {
  if !children.is_empty() {
    return Err(
      span.diagnostic(
        DiagnosticPhase::ContentModel,
        "style rules only accept declaration attributes",
      ),
    )
  }
  compile_css_rule(tag, attrs, scope, env, span).map(rule => Some(rule))
}

///|
fn normalize_css_scope(scope : String) -> String {
  let trimmed = scope.trim().to_owned()
  if is_explicit_css_scope_selector(trimmed) {
    return trimmed
  }
  "." + trimmed
}

///|
fn is_explicit_css_scope_selector(selector : String) -> Bool {
  [".", "#", "[", ":", "*"].any(prefix => selector.has_prefix(prefix))
}

///|
fn compile_css_rule(
  tag : String,
  attrs : Array[Attr],
  scope : String?,
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  scope_css_selector(tag, scope, span).bind(sel => {
    compile_css_declarations(attrs, env).map(decls => sel + "{" + decls + "}")
  })
}

///|
fn compile_css_declarations(
  attrs : Array[Attr],
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  let declarations : Array[String] = []
  for attr in attrs {
    match compile_css_declaration(attr, env) {
      Ok(declaration) => declarations.push(declaration)
      Err(error) => return Err(error)
    }
  }
  Ok(declarations.join(""))
}

///|
fn compile_css_declaration(
  attr : Attr,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  match attr.value {
    Some(value) =>
      value.to_scalar(env).map(text => attr.name + ":" + text + ";")
    None =>
      Err(
        attr.span.diagnostic(
          DiagnosticPhase::Type,
          "css declaration requires a value: " + attr.name,
        ),
      )
  }
}

///|
fn scope_css_selector(
  selector : String,
  scope : String?,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  let trimmed = selector.trim().to_owned()
  if trimmed.is_empty() {
    return Err(
      span.diagnostic(
        DiagnosticPhase::ContentModel,
        "css selector cannot be empty",
      ),
    )
  }
  if is_css_selector_list(trimmed) {
    return Err(
      span.diagnostic(
        DiagnosticPhase::ContentModel,
        "css selector lists are not supported; write separate rules",
      ),
    )
  }
  if scope is Some(scope_selector) {
    if css_selector_uses_scope_marker(trimmed) {
      return Ok(trimmed.replace_all(old="&", new=scope_selector))
    }
    return Ok(scope_selector + " " + trimmed)
  }
  if css_selector_uses_scope_marker(trimmed) {
    return Err(
      span.diagnostic(
        DiagnosticPhase::ContentModel,
        "css selector '&' requires a style scope",
      ),
    )
  }
  Ok(trimmed)
}

///|
fn is_css_selector_list(selector : String) -> Bool {
  selector.contains(",")
}

///|
fn css_selector_uses_scope_marker(selector : String) -> Bool {
  selector.contains("&")
}

///|
fn compile_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> Result[@sexp.HtmlAttrs, Diagnostic] {
  let html_attrs = @sexp.HtmlAttrs({})
  for attr in attrs {
    match attr.optional_scalar(env) {
      Ok(compiled) => html_attrs.upsert(attr.name, compiled)
      Err(error) => return Err(error)
    }
  }
  Ok(html_attrs)
}
