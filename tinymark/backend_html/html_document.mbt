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
priv struct DocumentHeadMetadata {
  charset : String?
  viewport : String?
  title : String?
  description : String?
  author : String?
}

///|
priv struct PaperRequest {
  options : @paper.PaperOptions
  span : SourceSpan
}

///|
priv struct DocumentMetadata {
  html_attrs : @sexp.HtmlAttrs
  body_attrs : @sexp.HtmlAttrs
  head : DocumentHeadMetadata
  staple : Bool
  paper : PaperRequest?
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
  let compiled = match
    compile_backend_nodes_full(
      nodes,
      env,
      options.initial_heading_level,
      options.wrap_inline_content,
      html_render_backend(),
      options.extensions,
      doc_attr_mode=DocAttrMode::CollectDocAttrs,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let metadata = match
    document_metadata(compiled.doc_attrs, compiled.env, options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let head = match
    html_head_nodes(metadata, compiled.head, options.extra_head) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    @sexp.render_html_document(
      metadata.html_attrs,
      head,
      [HtmlNode::Element("div", metadata.body_attrs, compiled.body)],
      options.doctype,
    ),
  )
}

///|
fn document_metadata(
  doc_attrs : Array[Attr],
  env : CompileEnv,
  options : HtmlDocumentOptions,
) -> Result[DocumentMetadata, Diagnostic] {
  let mut metadata = DocumentMetadata::from_options(options)
  for attr in doc_attrs {
    match metadata.apply_attr(attr, env) {
      Ok(next) => metadata = next
      Err(error) => return Err(error)
    }
  }
  if metadata.paper is Some(_) {
    metadata.body_attrs.append_class(@paper.PAPER_CLASS_NAME)
  }
  Ok(metadata)
}

///|
fn DocumentMetadata::from_options(
  options : HtmlDocumentOptions,
) -> DocumentMetadata {
  {
    html_attrs: @sexp.HtmlAttrs(Map([])),
    body_attrs: @sexp.HtmlAttrs(Map([])),
    head: {
      charset: options.charset,
      viewport: options.viewport,
      title: None,
      description: None,
      author: None,
    },
    staple: false,
    paper: None,
  }
}

///|
fn DocumentMetadata::apply_attr(
  self : DocumentMetadata,
  attr : Attr,
  env : CompileEnv,
) -> Result[DocumentMetadata, Diagnostic] {
  match attr.name {
    "lang" | "dir" => self.apply_html_attr(attr, env)
    "charset" =>
      self.with_head_value(attr, env, (head, value) => {
        ..head,
        charset: value,
      })
    "viewport" =>
      self.with_head_value(attr, env, (head, value) => {
        ..head,
        viewport: value,
      })
    "title" =>
      self.with_head_value(attr, env, (head, value) => { ..head, title: value })
    "description" =>
      self.with_head_value(attr, env, (head, value) => {
        ..head,
        description: value,
      })
    "author" =>
      self.with_head_value(attr, env, (head, value) => { ..head, author: value })
    "paper" => self.with_paper(attr, env)
    "staple" => self.with_staple(attr)
    _ => self.apply_body_attr(attr, env)
  }
}

///|
fn DocumentMetadata::apply_html_attr(
  self : DocumentMetadata,
  attr : Attr,
  env : CompileEnv,
) -> Result[DocumentMetadata, Diagnostic] {
  match compile_optional_attr_scalar(attr, env) {
    Ok(Some(text)) => {
      self.html_attrs.upsert(attr.name, Some(text))
      Ok(self)
    }
    Ok(None) => Ok(self)
    Err(error) => Err(error)
  }
}

///|
fn DocumentMetadata::with_head_value(
  self : DocumentMetadata,
  attr : Attr,
  env : CompileEnv,
  update : (DocumentHeadMetadata, String?) -> DocumentHeadMetadata,
) -> Result[DocumentMetadata, Diagnostic] {
  compile_optional_attr_scalar(attr, env).map(value => {
    let head = update(self.head, value)
    { ..self, head, }
  })
}

///|
fn DocumentMetadata::with_paper(
  self : DocumentMetadata,
  attr : Attr,
  env : CompileEnv,
) -> Result[DocumentMetadata, Diagnostic] {
  match required_attr_scalar(attr, env, "paper requires a value") {
    Ok(name) =>
      Ok({
        ..self,
        paper: Some({
          options: { slate_name: name, staple: self.staple },
          span: attr.span,
        }),
      })
    Err(error) => Err(error)
  }
}

///|
fn DocumentMetadata::with_staple(
  self : DocumentMetadata,
  attr : Attr,
) -> Result[DocumentMetadata, Diagnostic] {
  match
    flag_attr_bool(attr, "doc option requires a boolean value: " + attr.name) {
    Ok(value) => {
      let paper = match self.paper {
        Some(request) =>
          Some({ ..request, options: { ..request.options, staple: value } })
        None => None
      }
      Ok({ ..self, paper, staple: value })
    }
    Err(error) => Err(error)
  }
}

///|
fn DocumentMetadata::apply_body_attr(
  self : DocumentMetadata,
  attr : Attr,
  env : CompileEnv,
) -> Result[DocumentMetadata, Diagnostic] {
  match compile_optional_attr_scalar(attr, env) {
    Ok(value) => {
      self.body_attrs.upsert(attr.name, value)
      Ok(self)
    }
    Err(error) => Err(error)
  }
}

///|
fn html_head_nodes(
  metadata : DocumentMetadata,
  explicit_head : Array[HtmlNode],
  extra_head : Array[HtmlNode],
) -> Result[Array[HtmlNode], Diagnostic] {
  let head : Array[HtmlNode] = []

  if metadata.head.charset is Some(text) {
    head.push(
      HtmlNode::Element("meta", @sexp.HtmlAttrs({ "charset": Some(text) }), []),
    )
  }

  if metadata.head.viewport is Some(text) {
    head.push(html_named_meta("viewport", text))
  }

  if metadata.head.title is Some(text) {
    head.push(
      HtmlNode::Element("title", @sexp.HtmlAttrs(Map([])), [
        HtmlNode::Text(text),
      ]),
    )
  }

  if metadata.head.description is Some(text) {
    head.push(html_named_meta("description", text))
  }

  if metadata.head.author is Some(text) {
    head.push(html_named_meta("author", text))
  }

  if metadata.paper is Some(request) {
    match @paper.paper_style_css(request.options, request.span) {
      Ok(css) => head.push(paper_style_node(css))
      Err(error) => return Err(error)
    }
  }

  head.append(extra_head)
  head.append(explicit_head)
  Ok(head)
}

///|
fn paper_style_node(css : String) -> HtmlNode {
  HtmlNode::Element("style", @sexp.HtmlAttrs(Map([])), [HtmlNode::RawHtml(css)])
}

///|
fn html_named_meta(name : String, content : String) -> HtmlNode {
  HtmlNode::Element(
    "meta",
    @sexp.HtmlAttrs({ "name": Some(name), "content": Some(content) }),
    [],
  )
}
