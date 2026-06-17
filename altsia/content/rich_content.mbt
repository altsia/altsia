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
  compile_rich_content_with_wrap(
    doc,
    env.unwrap_or(@core.CompileEnv::empty()),
    wrap_paragraphs=true,
  )
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
  lower_node_sequence(doc.nodes, compile_env).map(nodes => {
    nodes,
    wrap_inline_content: wrap_paragraphs,
  })
}

///|
fn lower_node_sequence(
  nodes : Array[@core.Node],
  env : @core.CompileEnv,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  let out : Array[@model.RichContentNode] = []
  let local_env = @core.collect_scope_env(nodes, env)
  for node in nodes {
    match node {
      Let(name, value, _) => local_env.bind_value(name, value)
      Def(name, params, body, _) => local_env.bind_template(name, params, body)
      Doc(attrs, _) =>
        for attr in attrs {
          local_env.bind_doc_attr(attr)
        }
      _ =>
        match lower_node(node, local_env) {
          Ok(nodes) => out.append(nodes)
          Err(error) => return Err(error)
        }
    }
  }
  Ok(out)
}

///|
fn lower_node(
  node : @core.Node,
  env : @core.CompileEnv,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  match node {
    Text(text, span) => Ok([@model.RichText(text, span)])
    TextInterp(template, span) =>
      @core.interpolate_scalar(template, env, span).map(text => {
        [@model.RichText(text, span)]
      })
    Ref(name, span) => {
      if env.lookup_value(name) is Some(value) {
        return lower_value(value, env)
      }
      if env.lookup_template(name) is Some(template) {
        return expand_template(template, [], [], env, span)
      }
      lower_element(name, [], [], env, span)
    }
    Element(tag, attrs, children, span) => {
      if env.lookup_template(tag) is Some(template) {
        return expand_template(template, attrs, children, env, span)
      }
      lower_element(source_tag_name(tag), attrs, children, env, span)
    }
    When(name, children, span) =>
      match @core.bool_binding(env, name, span) {
        Ok(true) => lower_node_sequence(children, env)
        Ok(false) => Ok([])
        Err(error) => Err(error)
      }
    Unless(name, children, span) =>
      match @core.bool_binding(env, name, span) {
        Ok(true) => Ok([])
        Ok(false) => lower_node_sequence(children, env)
        Err(error) => Err(error)
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => Ok([])
  }
}

///|
fn lower_element(
  tag : String,
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  match tag {
    "_" => lower_node_sequence(children, env)
    "link" => lower_link(children, env, span)
    "embed" => lower_embed(attrs, children, env, span)
    _ =>
      normalize_attrs(attrs, env).bind(attrs => {
        lower_node_sequence(children, env).map(children => {
          [@model.RichElement(tag, attrs, children, span)]
        })
      })
  }
}

///|
fn lower_link(
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  guard children.get(0).bind(node => text_from_node(node, env~)) is Some(target) else {
    return Err(@model.diagnostic(span, Binding, "(link ...) requires a target"))
  }
  Ok([
    @model.RichDirective(
      @model.RichLinkDirective({
        target,
        text: rest_text(children, start=1, env~),
        span,
      }),
    ),
  ])
}

///|
fn lower_embed(
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  guard embed_target(children, env) is Some(target) else {
    return Err(
      @model.diagnostic(span, Binding, "(embed ...) requires a target"),
    )
  }
  embed_option_from_attrs(attrs, env).map(option => {
    [
      @model.RichDirective(
        @model.RichEmbedDirective({
          target,
          title: rest_text(children, start=1, env~),
          option,
          span,
        }),
      ),
    ]
  })
}

///|
fn lower_value(
  value : @core.Value,
  env : @core.CompileEnv,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  match value {
    Scalar(text, span) => Ok([@model.RichText(text, span)])
    Bool(value, span) =>
      Ok([@model.RichText(if value { "true" } else { "false" }, span)])
    Interp(template, span) =>
      @core.interpolate_scalar(template, env, span).map(text => {
        [@model.RichText(text, span)]
      })
    Fragment(nodes, _) => lower_node_sequence(nodes, env)
  }
}

///|
fn expand_template(
  template : @core.Template,
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  call_env : @core.CompileEnv,
  call_span : @core.SourceSpan,
) -> Result[Array[@model.RichContentNode], @core.Diagnostic] {
  @core.bind_template_call_env(template, attrs, children, call_env, call_span).bind(env => {
      lower_node_sequence(template.body, env)
    },
  )
}

///|
fn normalize_attrs(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Result[Array[@core.Attr], @core.Diagnostic] {
  let normalized : Array[@core.Attr] = []
  for attr in attrs {
    match attr.value {
      None => normalized.push(attr)
      Some(value) =>
        match @core.value_to_scalar(value, env) {
          Ok(text) =>
            normalized.push({
              name: attr.name,
              value: Some(Scalar(text, attr.span)),
              span: attr.span,
            })
          Err(error) => return Err(error)
        }
    }
  }
  Ok(normalized)
}

///|
fn source_tag_name(tag : String) -> String {
  match tag {
    "-" => "item"
    _ => tag
  }
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
