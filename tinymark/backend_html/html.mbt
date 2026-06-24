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
  html_attrs : Array[(String, String?)]
  scope : String?
}

///|
pub(all) struct ElementCall {
  tag : String
  attrs : Array[Attr]
  children : Array[Node]
  span : SourceSpan
}

///|
pub(all) struct CompileContext {
  env : CompileEnv

  // Heading level used for section titles at this element position.
  current_heading_level : Int

  // Compile children as inline flow and return both body and routed head nodes.
  compile_inline : (Array[Node]) -> Result[ElementOutput, Diagnostic]

  // Compile children as block flow and return both body and routed head nodes.
  compile_block : (Array[Node]) -> Result[ElementOutput, Diagnostic]

  // Compile children as block flow at a specific heading level.
  compile_block_at : (Array[Node], Int) -> Result[ElementOutput, Diagnostic]

  // Compile children using the backend's mixed-flow paragraph detection.
  compile_mixed : (Array[Node]) -> Result[ElementOutput, Diagnostic]

  // Compile children as plain text content.
  compile_text_only : (Array[Node]) -> Result[String, Diagnostic]
}

///|
pub struct CallContext {
  call : ElementCall
  context : CompileContext
}

///|
priv struct ElementCompileInput {
  call : ElementCall
  env : CompileEnv
  current_heading_level : Int
  extensions : Array[ElementResolver]
}

///|
pub(all) struct ElementOutput {
  body : Array[HtmlNode]
  head : Array[HtmlNode]
}

///|
priv struct CompiledNodeSequence {
  body : Array[HtmlNode]
  head : Array[HtmlNode]
  doc_attrs : Array[Attr]
  env : CompileEnv
}

///|
priv enum DocAttrMode {
  BindDocAttrs
  CollectDocAttrs
}

///|
pub fn ElementOutput::empty() -> ElementOutput {
  { body: [], head: [] }
}

///|
pub fn ElementOutput::body(nodes : Array[HtmlNode]) -> ElementOutput {
  { body: nodes, head: [] }
}

///|
pub fn ElementOutput::head(nodes : Array[HtmlNode]) -> ElementOutput {
  { body: [], head: nodes }
}

///|
fn body_output(nodes : Array[HtmlNode]) -> ElementOutput {
  ElementOutput::body(nodes)
}

///|
pub type ElementResolver = (CallContext) -> Result[ElementOutput?, Diagnostic]

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
  compile_node_sequence(
    doc.nodes,
    compile_env,
    compile_options.initial_heading_level,
    compile_options.wrap_inline_content,
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
fn compile_node_sequence(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  extensions : Array[ElementResolver],
) -> Result[Array[HtmlNode], Diagnostic] {
  compile_node_sequence_output(
    nodes, env, current_heading_level, wrap_inline_content, extensions,
  ).map(output => output.body)
}

///|
fn compile_node_sequence_output(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  compile_node_sequence_full(
    nodes,
    env,
    current_heading_level,
    wrap_inline_content,
    extensions,
    doc_attr_mode=BindDocAttrs,
  ).map(compiled => { body: compiled.body, head: compiled.head })
}

///|
fn compile_node_sequence_full(
  nodes : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  wrap_inline_content : Bool,
  extensions : Array[ElementResolver],
  doc_attr_mode~ : DocAttrMode,
) -> Result[CompiledNodeSequence, Diagnostic] {
  let out : Array[HtmlNode] = []
  let head : Array[HtmlNode] = []
  let doc_attrs : Array[Attr] = []
  let inline_run : Array[HtmlNode] = []
  let local_env = collect_scope_env(nodes, env)
  for node in nodes {
    match node {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Doc(attrs, _) =>
        for attr in attrs {
          match doc_attr_mode {
            CollectDocAttrs => doc_attrs.push(attr)
            BindDocAttrs => ()
          }
          local_env.bind_doc_attr(attr)
        }
      _ =>
        match compile_node(node, local_env, current_heading_level, extensions) {
          Err(error) => return Err(error)
          Ok(compiled) => {
            head.append(compiled.head)
            for html_node in compiled.body {
              append_compiled_node(
                inline_run, out, html_node, wrap_inline_content,
              )
            }
          }
        }
    }
  }
  flush_paragraph(inline_run, out)
  Ok({ body: out, head, doc_attrs, env: local_env })
}

///|
fn compile_inline_children_output(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  compile_node_sequence_output(
    children, env, current_heading_level, false, extensions,
  )
}

///|
fn compile_block_children_output(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  compile_node_sequence_output(
    children, env, current_heading_level, true, extensions,
  )
}

///|
fn compile_mixed_children_output(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  compile_node_sequence_output(
    children,
    env,
    current_heading_level,
    children_need_paragraphs(children, env),
    extensions,
  )
}

///|
fn compile_node(
  node : Node,
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  match node {
    Text(text, _) => Ok(body_output([HtmlNode::Text(text)]))
    TextInterp(template, span) =>
      interpolate_scalar(template, env, span).map(value => {
        body_output([HtmlNode::Text(value)])
      })
    Ref(name, span) => {
      if env.lookup_value(name) is Some(value) {
        return value_to_nodes(value, env, current_heading_level, extensions)
      }
      if env.lookup_template(name) is Some(template) {
        return expand_template(
          template,
          [],
          [],
          env,
          current_heading_level,
          span,
          extensions,
        )
      }
      compile_element({
        call: { tag: name, attrs: [], children: [], span },
        env,
        current_heading_level,
        extensions,
      })
    }
    Element(tag, attrs, children, span) => {
      if env.lookup_template(tag) is Some(template) {
        return expand_template(
          template, attrs, children, env, current_heading_level, span, extensions,
        )
      }
      compile_element({
        call: { tag: source_tag_name(tag), attrs, children, span },
        env,
        current_heading_level,
        extensions,
      })
    }
    When(name, children, span) =>
      match bool_binding(env, name, span) {
        Ok(true) =>
          compile_inline_children_output(
            children, env, current_heading_level, extensions,
          )
        Ok(false) => Ok(ElementOutput::empty())
        Err(error) => Err(error)
      }
    Unless(name, children, span) =>
      match bool_binding(env, name, span) {
        Ok(true) => Ok(ElementOutput::empty())
        Ok(false) =>
          compile_inline_children_output(
            children, env, current_heading_level, extensions,
          )
        Err(error) => Err(error)
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => Ok(ElementOutput::empty())
  }
}

///|
fn compile_element(
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
  let call = input.call
  let env = input.env
  let current_heading_level = input.current_heading_level
  let extensions = input.extensions
  let context : CompileContext = {
    env,
    current_heading_level,
    compile_inline: children => {
      compile_inline_children_output(
        children, env, current_heading_level, extensions,
      )
    },
    compile_block: children => {
      compile_block_children_output(
        children, env, current_heading_level, extensions,
      )
    },
    compile_block_at: (children, heading_level) => {
      compile_block_children_output(children, env, heading_level, extensions)
    },
    compile_mixed: children => {
      compile_mixed_children_output(
        children, env, current_heading_level, extensions,
      )
    },
    compile_text_only: children => {
      compile_text_only_children(
        children, env, current_heading_level, extensions,
      )
    },
  }
  let compiler = CallContext::{ call, context }
  for resolver in element_resolvers(extensions) {
    let result = resolver(compiler)
    if result is Ok(Some(output)) {
      return Ok(output)
    }
    if result is Err(error) {
      return Err(error)
    }
  }
  match compiler.compile_prelude_element() {
    Ok(Some(output)) => return Ok(output)
    Err(error) => return Err(error)
    _ => ()
  }
  match call.tag {
    "style" => compile_scoped_style(input)
    _ => compile_mapped_element(call.tag, input)
  }
}

///|
fn element_resolvers(
  extensions : Array[ElementResolver],
) -> Array[ElementResolver] {
  let resolvers = extensions.copy()
  resolvers.push(html_head_resolver)
  resolvers
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
    Some({ body: [], head })
  })
}

///|
fn source_tag_name(tag : String) -> String {
  match tag {
    "-" => "item"
    _ => tag
  }
}

///|
fn compile_mapped_element(
  tag : String,
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
  compile_attrs(input.call.attrs, input.env).bind(html_attrs => {
    compile_children_for_tag_output(tag, input).map(output => {
      body: [HtmlNode::Element(tag, html_attrs, output.body)],
      head: output.head,
    })
  })
}

///|
fn compile_children_for_tag_output(
  tag : String,
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
  match content_model(tag) {
    InlineOnly =>
      compile_inline_children_output(
        input.call.children,
        input.env,
        input.current_heading_level,
        input.extensions,
      )
    BlockFlow =>
      compile_block_children_output(
        input.call.children,
        input.env,
        input.current_heading_level,
        input.extensions,
      )
    MixedFlow =>
      compile_mixed_children_output(
        input.call.children,
        input.env,
        input.current_heading_level,
        input.extensions,
      )
  }
}

///|
fn content_model(tag : String) -> ContentModel {
  match tag {
    "blockquote" => ContentModel::BlockFlow
    "li" | "div" => ContentModel::MixedFlow
    _ => ContentModel::InlineOnly
  }
}

///|
fn children_need_paragraphs(children : Array[Node], env : CompileEnv) -> Bool {
  let local_env = collect_scope_env(children, env)
  for child in children {
    match child {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Doc(attrs, _) =>
        for attr in attrs {
          local_env.bind_doc_attr(attr)
        }
      _ => if node_needs_paragraph_context(child, local_env) { return true }
    }
  }
  false
}

///|
fn node_needs_paragraph_context(node : Node, env : CompileEnv) -> Bool {
  match node {
    Text(text, _) => has_paragraph_break(text)
    TextInterp(template, _) => interpolation_has_paragraph_break(template)
    Element("html.head", _, _, _) => false
    Element(tag, _, _, _) => is_source_block_tag(tag)
    Ref(name, _) =>
      match env.lookup_value(name) {
        Some(Scalar(text, _)) => has_paragraph_break(text)
        Some(Interp(template, _)) => interpolation_has_paragraph_break(template)
        Some(Fragment(nodes, _)) => children_need_paragraphs(nodes, env)
        _ => false
      }
    When(name, children, span) =>
      match bool_binding(env, name, span) {
        Ok(true) => children_need_paragraphs(children, env)
        _ => false
      }
    Unless(name, children, span) =>
      match bool_binding(env, name, span) {
        Ok(false) => children_need_paragraphs(children, env)
        _ => false
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => false
  }
}

///|
fn interpolation_has_paragraph_break(template : Interpolation) -> Bool {
  template.any(part => part is Literal(text) && has_paragraph_break(text))
}

///|
fn is_source_block_tag(tag : String) -> Bool {
  let normalized = source_tag_name(tag)
  match Prelude::is_block(normalized) {
    Some(value) => value
    None =>
      ["table", "thead", "tbody", "tr", "p", "blockquote", "hr", "style"].contains(
        normalized,
      )
  }
}

///|
fn compile_scoped_style(
  input : ElementCompileInput,
) -> Result[ElementOutput, Diagnostic] {
  compile_style_attrs(input.call.attrs, input.env).bind(style_attrs => {
    compile_css_rule_nodes(input.call.children, style_attrs.scope, input.env).map(rules => {
        body_output([
          HtmlNode::Element("style", style_attrs.html_attrs, [
            HtmlNode::RawHtml(rules.join("")),
          ]),
        ])
      },
    )
  })
}

///|
fn compile_style_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> Result[CssStyleAttrs, Diagnostic] {
  let html_attrs : Array[(String, String?)] = []
  let mut scope : String? = None
  for attr in attrs {
    if attr.name == "scope" {
      match compile_style_scope(attr, env) {
        Ok(value) => scope = Some(value)
        Err(error) => return Err(error)
      }
      continue
    }
    match compile_attr_value(attr.value, env) {
      Ok(compiled) => html_attrs.push((attr.name, compiled))
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
fn expand_template(
  template : Template,
  attrs : Array[Attr],
  children : Array[Node],
  call_env : CompileEnv,
  current_heading_level : Int,
  call_span : SourceSpan,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  bind_template_call_env(template, attrs, children, call_env, call_span).bind(template_env => {
    compile_inline_children_output(
      template.body,
      template_env,
      current_heading_level,
      extensions,
    )
  })
}

///|
fn compile_text_only_children(
  children : Array[Node],
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[String, Diagnostic] {
  let parts : Array[String] = []
  let local_env = collect_scope_env(children, env)
  for child in children {
    match child {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Doc(attrs, _) =>
        for attr in attrs {
          local_env.bind_doc_attr(attr)
        }
      _ => {
        let nodes = match
          compile_node(child, local_env, current_heading_level, extensions) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        if !nodes.head.is_empty() {
          return Err(
            child
            .span()
            .diagnostic(
              DiagnosticPhase::ContentModel,
              "expected plain text content",
            ),
          )
        }
        for node in nodes.body {
          match node {
            HtmlNode::Text(text) => parts.push(text)
            _ =>
              return Err(
                child
                .span()
                .diagnostic(
                  DiagnosticPhase::ContentModel,
                  "expected plain text content",
                ),
              )
          }
        }
      }
    }
  }
  Ok(parts.join(""))
}

///|
fn compile_attrs(
  attrs : Array[Attr],
  env : CompileEnv,
) -> Result[Array[(String, String?)], Diagnostic] {
  let html_attrs : Array[(String, String?)] = []
  for attr in attrs {
    match compile_attr_value(attr.value, env) {
      Ok(compiled) => html_attrs.push((attr.name, compiled))
      Err(error) => return Err(error)
    }
  }
  Ok(html_attrs)
}

///|
fn compile_attr_value(
  value : Value?,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  match value {
    None => Ok(None)
    Some(v) => v.to_scalar(env).map(text => Some(text))
  }
}

///|
fn value_to_nodes(
  value : Value,
  env : CompileEnv,
  current_heading_level : Int,
  extensions : Array[ElementResolver],
) -> Result[ElementOutput, Diagnostic] {
  match value {
    Scalar(text, _) => Ok(body_output([HtmlNode::Text(text)]))
    Bool(value, _) =>
      Ok(body_output([HtmlNode::Text(if value { "true" } else { "false" })]))
    Interp(template, span) =>
      interpolate_scalar(template, env, span).map(text => {
        body_output([HtmlNode::Text(text)])
      })
    Fragment(nodes, _) =>
      compile_inline_children_output(
        nodes, env, current_heading_level, extensions,
      )
  }
}
