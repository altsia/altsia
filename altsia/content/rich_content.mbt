///|
pub fn text_from_node(node : @core.Node, env? : @core.CompileEnv) -> String? {
  match node {
    Text(text, _) => Some(text)
    TextInterp(_, _) =>
      match
        (match env {
          Some(env) => @core.nodes_to_plain_text([node], env~)
          None => @core.nodes_to_plain_text([node])
        }) {
        Ok(text) => Some(text)
        Err(_) => None
      }
    _ => None
  }
}

///|
pub fn compile_rich_content(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[@model.RichContent, @core.Diagnostic] {
  match env {
    Some(env) => compile_rich_content_with_wrap(doc, env, wrap_paragraphs=true)
    None =>
      compile_rich_content_with_wrap(
        doc,
        @core.CompileEnv::empty(),
        wrap_paragraphs=true,
      )
  }
}

///|
pub fn compile_inline_rich_content(
  doc : @core.Document,
  env : @core.CompileEnv,
) -> Result[@model.RichContent, @core.Diagnostic] {
  compile_rich_content_with_wrap(doc, env, wrap_paragraphs=false)
}

///|
fn compile_rich_content_with_wrap(
  doc : @core.Document,
  compile_env : @core.CompileEnv,
  wrap_paragraphs~ : Bool,
) -> Result[@model.RichContent, @core.Diagnostic] {
  let captured : Array[@model.RichContentDirective] = []
  let resolver : @html.ElementResolver = (call, context) => {
    match call.tag {
      "link" => {
        let target = match
          call.children
          .get(0)
          .bind(node => text_from_node(node, env=context.env)) {
          Some(value) => value
          None =>
            return Err(
              @model.diagnostic(
                call.span,
                Binding,
                "(link ...) requires a target",
              ),
            )
        }
        let index = captured.length()
        captured.push(
          @model.RichLinkDirective({
            target,
            text: rest_text(call.children, start=1, env=context.env),
            span: call.span,
          }),
        )
        Ok(
          Some(
            @html.ElementOutput::body([
              @sexp.SexpNode::Text(chunk_marker(index)),
            ]),
          ),
        )
      }
      "embed" => {
        let target = match embed_target(call.children, context.env) {
          Some(value) => value
          None =>
            return Err(
              @model.diagnostic(
                call.span,
                Binding,
                "(embed ...) requires a target",
              ),
            )
        }
        let option = match embed_option_from_attrs(call.attrs, context.env) {
          Ok(option) => option
          Err(error) => return Err(error)
        }
        let index = captured.length()
        captured.push(
          @model.RichEmbedDirective({
            target,
            title: rest_text(call.children, start=1, env=context.env),
            option,
            span: call.span,
          }),
        )
        Ok(
          Some(
            @html.ElementOutput::body([
              @sexp.SexpNode::RawHtml(chunk_marker(index)),
            ]),
          ),
        )
      }
      _ => Ok(None)
    }
  }
  let options = @html.CompileOptions::fragment()
  let options = {
    ..options,
    wrap_inline_content: wrap_paragraphs,
    extensions: [resolver],
  }
  match @html.compile_fragment(doc, env=compile_env, options~) {
    Ok(nodes) =>
      Ok(rich_content_from_marked_html(@sexp.render_html(nodes), captured))
    Err(error) => Err(error)
  }
}

///|
fn chunk_marker(index : Int) -> String {
  "\u{1f}altsia:" + index.to_string() + "\u{1f}"
}

///|
fn rich_content_from_marked_html(
  html : String,
  captured : Array[@model.RichContentDirective],
) -> @model.RichContent {
  let result : @model.RichContent = []
  let mut remainder = html
  for i in 0..<captured.length() {
    let marker = chunk_marker(i)
    let parts = remainder.split(marker).to_array()
    if parts.length() > 1 {
      let before = parts[0].to_owned()
      if before != "" {
        result.push(@model.HtmlChunk(before))
      }
      result.push(@model.DirectiveChunk(captured[i]))
      remainder = parts[1:].to_owned().map(part => part.to_owned()).join(marker)
    }
  }
  if remainder != "" {
    result.push(@model.HtmlChunk(remainder))
  }
  result
}

///|
fn rest_text(
  children : Array[@core.Node],
  start~ : Int,
  env~ : @core.CompileEnv,
) -> String? {
  let parts = children[start:]
    .to_owned()
    .filter_map(node => text_from_node(node, env~))
  if parts.is_empty() {
    None
  } else {
    Some(parts.join(" ").trim().to_owned())
  }
}

///|
fn embed_target(
  children : Array[@core.Node],
  env : @core.CompileEnv,
) -> String? {
  children.get(0).bind(node => text_from_node(node, env~))
}

///|
fn embed_option_from_attrs(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Result[@model.EmbedOption, @core.Diagnostic] {
  let mut option = @model.EmbedOption::default()
  for attr in attrs {
    let value = match embed_bool_attr(attr, env) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match attr.name {
      "numbering" => option = { ..option, numbering: value }
      "details-open" => option = { ..option, details_open: value }
      "catalog" => option = { ..option, catalog: value }
      _ =>
        return Err(
          @model.diagnostic(
            attr.span,
            Type,
            "unknown embed option: " + attr.name,
          ),
        )
    }
  }
  Ok(option)
}

///|
fn embed_bool_attr(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> Result[Bool, @core.Diagnostic] {
  match attr.value {
    None => Ok(true)
    Some(value) =>
      match @core.value_to_scalar(value, env) {
        Ok("true") => Ok(true)
        Ok("false") => Ok(false)
        Ok(_) =>
          Err(
            @model.diagnostic(
              attr.span,
              Type,
              "embed option requires a boolean value: " + attr.name,
            ),
          )
        Err(error) => Err(error)
      }
  }
}
