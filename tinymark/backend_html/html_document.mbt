///|
pub(all) struct HtmlDocumentOptions {
  // Heading level for top-level section titles; nested sections increment it.
  initial_heading_level : Int

  // Wrap contiguous inline output in <p> elements when compiling body content.
  wrap_inline_content : Bool

  // Element resolvers consulted before built-in HTML element handling.
  extensions : Array[ElementResolver]

  // Optional document type passed to the HTML renderer.
  doctype : String?

  // Default charset meta value unless overridden by `(meta (:charset ...))`.
  charset : String?

  // Default viewport meta value unless overridden by `(meta (:viewport ...))`.

  viewport : String?

  // Extra nodes appended to <head> before explicit `html.head` output.
  extra_head : Array[HtmlNode]
}

///|
pub fn HtmlDocumentOptions::default() -> HtmlDocumentOptions {
  {
    initial_heading_level: 1,
    wrap_inline_content: true,
    extensions: [],
    doctype: Some("html"),
    charset: Some("utf-8"),
    viewport: Some("width=device-width, initial-scale=1"),
    extra_head: [],
  }
}

///|
pub fn HtmlDocumentOptions::empty() -> HtmlDocumentOptions {
  {
    initial_heading_level: 1,
    wrap_inline_content: true,
    extensions: [],
    doctype: None,
    charset: None,
    viewport: None,
    extra_head: [],
  }
}

///|
pub fn compile_html_document(
  doc : Document,
  env? : CompileEnv,
  options? : HtmlDocumentOptions,
) -> Result[String, Diagnostic] {
  let compile_env = env.unwrap_or(CompileEnv::empty())
  let document_options = options.unwrap_or(HtmlDocumentOptions::default())
  compile_html_document_nodes(doc.nodes, compile_env, document_options)
}

///|
fn compile_html_document_nodes(
  nodes : Array[Node],
  env : CompileEnv,
  options : HtmlDocumentOptions,
) -> Result[String, Diagnostic] {
  let meta_attrs : Array[Attr] = []
  let explicit_head : Array[HtmlNode] = []
  let body : Array[HtmlNode] = []
  let inline_run : Array[HtmlNode] = []
  let local_env = collect_scope_env(nodes, env)
  for node in nodes {
    match node {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Meta(attrs, _) =>
        for attr in attrs {
          meta_attrs.push(attr)
          local_env.bind_meta_attr(attr)
        }
      _ =>
        match
          compile_node(
            node,
            local_env,
            options.initial_heading_level,
            options.extensions,
          ) {
          Err(error) => return Err(error)
          Ok(compiled) => {
            explicit_head.append(compiled.head)
            for html_node in compiled.body {
              append_compiled_node(
                inline_run,
                body,
                html_node,
                options.wrap_inline_content,
              )
            }
          }
        }
    }
  }
  flush_paragraph(inline_run, body)
  html_document_attrs(meta_attrs, local_env).bind(html_attrs => {
    html_head_nodes(meta_attrs, explicit_head, local_env, options).map(head => {
      @sexp.render_html_document(html_attrs, head, body, options.doctype)
    })
  })
}

///|
fn html_document_attrs(
  meta_attrs : Array[Attr],
  env : CompileEnv,
) -> Result[Array[(String, String?)], Diagnostic] {
  let attrs : Array[(String, String?)] = []
  for attr in meta_attrs {
    if !is_html_document_attr(attr.name) {
      continue
    }
    guard attr.value is Some(value) else { continue }
    match value_to_scalar(value, env) {
      Ok(text) => @sexp.upsert_attr(attrs, attr.name, Some(text))
      Err(error) => return Err(error)
    }
  }
  Ok(attrs)
}

///|
fn is_html_document_attr(name : String) -> Bool {
  ["lang", "dir"].contains(name)
}

///|
fn html_head_nodes(
  meta_attrs : Array[Attr],
  explicit_head : Array[HtmlNode],
  env : CompileEnv,
  options : HtmlDocumentOptions,
) -> Result[Array[HtmlNode], Diagnostic] {
  let head : Array[HtmlNode] = []
  let charset = match
    meta_scalar_or_default(meta_attrs, "charset", options.charset, env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if charset is Some(text) {
    head.push(HtmlNode::Element("meta", [("charset", Some(text))], []))
  }
  let viewport = match
    meta_scalar_or_default(meta_attrs, "viewport", options.viewport, env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if viewport is Some(text) {
    head.push(html_named_meta("viewport", text))
  }
  if push_optional_head_meta(head, meta_attrs, env) is Err(error) {
    return Err(error)
  }
  head.append(options.extra_head)
  head.append(explicit_head)
  Ok(head)
}

///|
fn push_optional_head_meta(
  head : Array[HtmlNode],
  meta_attrs : Array[Attr],
  env : CompileEnv,
) -> Result[Unit, Diagnostic] {
  push_optional_meta_node(head, meta_attrs, "title", env, text => {
    HtmlNode::Element("title", [], [HtmlNode::Text(text)])
  })
  .bind(_ => {
    push_optional_meta_node(head, meta_attrs, "description", env, text => {
      html_named_meta("description", text)
    })
  })
  .bind(_ => {
    push_optional_meta_node(head, meta_attrs, "author", env, text => {
      html_named_meta("author", text)
    })
  })
}

///|
fn push_optional_meta_node(
  head : Array[HtmlNode],
  meta_attrs : Array[Attr],
  name : String,
  env : CompileEnv,
  make_node : (String) -> HtmlNode,
) -> Result[Unit, Diagnostic] {
  meta_scalar(meta_attrs, name, env).map(text_opt => {
    if text_opt is Some(text) {
      head.push(make_node(text))
    }
  })
}

///|
fn meta_scalar_or_default(
  meta_attrs : Array[Attr],
  key : String,
  default : String?,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  meta_scalar(meta_attrs, key, env).map(found => {
    match found {
      Some(_) => found
      None => default
    }
  })
}

///|
fn meta_scalar(
  meta_attrs : Array[Attr],
  key : String,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  let mut found : String? = None
  for attr in meta_attrs {
    if attr.name != key {
      continue
    }
    guard attr.value is Some(value) else { continue }
    match value_to_scalar(value, env) {
      Ok(text) => found = Some(text)
      Err(error) => return Err(error)
    }
  }
  Ok(found)
}

///|
fn html_named_meta(name : String, content : String) -> HtmlNode {
  HtmlNode::Element(
    "meta",
    [("name", Some(name)), ("content", Some(content))],
    [],
  )
}
