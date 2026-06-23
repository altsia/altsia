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

  // Default charset meta value unless overridden by `(doc (:charset ...))`.
  charset : String?

  // Default viewport meta value unless overridden by `(doc (:viewport ...))`.

  viewport : String?

  // Extra nodes appended to <head> before explicit `html.head` output.
  extra_head : Array[HtmlNode]
}

///|
priv struct DocumentHeadSettings {
  charset : String?
  viewport : String?
  title : String?
  description : String?
  author : String?
}

///|
priv struct DocumentSettings {
  html_attrs : Array[(String, String?)]
  body_attrs : Array[(String, String?)]
  head : DocumentHeadSettings
  paper : ComputedPaper?
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
  let doc_attrs : Array[Attr] = []
  let explicit_head : Array[HtmlNode] = []
  let body : Array[HtmlNode] = []
  let inline_run : Array[HtmlNode] = []
  let local_env = collect_scope_env(nodes, env)
  for node in nodes {
    match node {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Doc(attrs, _) =>
        for attr in attrs {
          doc_attrs.push(attr)
          local_env.bind_doc_attr(attr)
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
  let settings = match document_settings(doc_attrs, local_env, options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let head = html_head_nodes(settings, explicit_head, options.extra_head)
  Ok(
    @sexp.render_html_document(
      settings.html_attrs,
      head,
      [HtmlNode::Element("div", settings.body_attrs, body)],
      options.doctype,
    ),
  )
}

///|
fn document_settings(
  doc_attrs : Array[Attr],
  env : CompileEnv,
  options : HtmlDocumentOptions,
) -> Result[DocumentSettings, Diagnostic] {
  let html_attrs : Array[(String, String?)] = []
  let body_attrs : Array[(String, String?)] = []
  let mut charset = options.charset
  let mut viewport = options.viewport
  let mut title : String? = None
  let mut description : String? = None
  let mut author : String? = None
  let mut paper_options : (PaperOptions, SourceSpan)? = None
  let mut staple = false
  for attr in doc_attrs {
    match attr.name {
      "lang" | "dir" =>
        match optional_doc_scalar(attr, env) {
          Ok(Some(text)) =>
            @sexp.HtmlAttrs(html_attrs).upsert(attr.name, Some(text))
          Ok(None) => ()
          Err(error) => return Err(error)
        }
      "charset" =>
        match optional_doc_scalar(attr, env) {
          Ok(value) => charset = value
          Err(error) => return Err(error)
        }
      "viewport" =>
        match optional_doc_scalar(attr, env) {
          Ok(value) => viewport = value
          Err(error) => return Err(error)
        }
      "title" =>
        match optional_doc_scalar(attr, env) {
          Ok(value) => title = value
          Err(error) => return Err(error)
        }
      "description" =>
        match optional_doc_scalar(attr, env) {
          Ok(value) => description = value
          Err(error) => return Err(error)
        }
      "author" =>
        match optional_doc_scalar(attr, env) {
          Ok(value) => author = value
          Err(error) => return Err(error)
        }
      "paper" =>
        match required_doc_scalar(attr, env, "paper requires a value") {
          Ok(name) =>
            paper_options = Some(({ slate_name: name, staple }, attr.span))
          Err(error) => return Err(error)
        }
      "staple" =>
        match doc_bool_attr(attr, env) {
          Ok(value) => {
            staple = value
            if paper_options is Some((options, span)) {
              paper_options = Some(({ ..options, staple: value }, span))
            }
          }
          Err(error) => return Err(error)
        }
      _ =>
        match compile_attr_value(attr.value, env) {
          Ok(value) => body_attrs.push((attr.name, value))
          Err(error) => return Err(error)
        }
    }
  }
  let paper = match paper_options {
    Some((options, span)) =>
      match compute_paper(options, span) {
        Ok(paper) => Some(paper)
        Err(error) => return Err(error)
      }
    None => None
  }
  if paper is Some(_) {
    merge_body_class(body_attrs, "\{PAPER_CLASS_NAME}")
  }
  Ok({
    html_attrs,
    body_attrs,
    head: { charset, viewport, title, description, author },
    paper,
  })
}

///|
fn html_head_nodes(
  settings : DocumentSettings,
  explicit_head : Array[HtmlNode],
  extra_head : Array[HtmlNode],
) -> Array[HtmlNode] {
  let head : Array[HtmlNode] = []

  if settings.head.charset is Some(text) {
    head.push(HtmlNode::Element("meta", [("charset", Some(text))], []))
  }

  if settings.head.viewport is Some(text) {
    head.push(html_named_meta("viewport", text))
  }

  if settings.head.title is Some(text) {
    head.push(HtmlNode::Element("title", [], [HtmlNode::Text(text)]))
  }

  if settings.head.description is Some(text) {
    head.push(html_named_meta("description", text))
  }

  if settings.head.author is Some(text) {
    head.push(html_named_meta("author", text))
  }

  if settings.paper is Some(spec) {
    head.push(paper_style_node(spec))
  }

  head.append(extra_head)
  head.append(explicit_head)
  head
}

///|
fn merge_body_class(
  attrs : Array[(String, String?)],
  class_name : String,
) -> Unit {
  for index, attr in attrs {
    let (name, value) = attr
    if name == "class" {
      let merged = match value {
        None => class_name
        Some(text) if text.trim().is_empty() => class_name
        Some(text) => text + " " + class_name
      }
      attrs[index] = (name, Some(merged))
      return
    }
  }
  attrs.push(("class", Some(class_name)))
}

///|
fn optional_doc_scalar(
  attr : Attr,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  match attr.value {
    Some(value) => value_to_scalar(value, env).map(text => Some(text))
    None => Ok(None)
  }
}

///|
fn required_doc_scalar(
  attr : Attr,
  env : CompileEnv,
  missing_message : String,
) -> Result[String, Diagnostic] {
  guard attr.value is Some(value) else {
    return Err(attr.span.diagnostic(DiagnosticPhase::Type, missing_message))
  }
  value_to_scalar(value, env)
}

///|
fn doc_bool_attr(attr : Attr, env : CompileEnv) -> Result[Bool, Diagnostic] {
  match attr.value {
    None => Ok(true)
    Some(value) =>
      value_to_scalar(value, env).bind(text => {
        match text {
          "true" => Ok(true)
          "false" => Ok(false)
          _ =>
            Err(
              attr.span.diagnostic(
                DiagnosticPhase::Type,
                "doc option requires a boolean value: " + attr.name,
              ),
            )
        }
      })
  }
}

///|
fn html_named_meta(name : String, content : String) -> HtmlNode {
  HtmlNode::Element(
    "meta",
    [("name", Some(name)), ("content", Some(content))],
    [],
  )
}
