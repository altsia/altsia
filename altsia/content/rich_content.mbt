///|
pub fn text_from_node(node : @core.Node, env? : @core.CompileEnv) -> String? {
  match node {
    Text(text, _) => Some(text)
    TextInterp(_, _) =>
      try @core.nodes_to_plain_text([node], env) catch {
        _ => None
      } noraise {
        text => Some(text)
      }
    _ => None
  }
}

///|
pub fn compile_rich_content(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> @model.RichContent raise @core.Diagnostic {
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
) -> @model.RichContent raise @core.Diagnostic {
  compile_rich_content_with_wrap(doc, env, wrap_paragraphs=false)
}

///|
fn compile_rich_content_with_wrap(
  doc : @core.Document,
  compile_env : @core.CompileEnv,
  wrap_paragraphs~ : Bool,
) -> @model.RichContent raise @core.Diagnostic {
  {
    nodes: lower_node_sequence(doc.nodes, compile_env),
    wrap_inline_content: wrap_paragraphs,
  }
}

///|
fn lower_node_sequence(
  nodes : Array[@core.Node],
  env : @core.CompileEnv,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
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
      _ => out.append(lower_node(node, local_env))
    }
  }
  out
}

///|
fn lower_node(
  node : @core.Node,
  env : @core.CompileEnv,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  match node {
    Text(text, span) => [@model.RichText(text, span)]
    TextInterp(template, span) =>
      [@model.RichText(@core.interpolate_scalar(template, env, span), span)]
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
      if @core.bool_binding(env, name, span) {
        lower_node_sequence(children, env)
      } else {
        []
      }
    Unless(name, children, span) =>
      if @core.bool_binding(env, name, span) {
        []
      } else {
        lower_node_sequence(children, env)
      }
    Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => []
  }
}

///|
fn lower_element(
  tag : String,
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  match tag {
    "_" => lower_node_sequence(children, env)
    "link" => lower_link(children, env, span)
    "embed" => lower_embed(attrs, children, env, span)
    _ =>
      [
        @model.RichElement(
          tag,
          normalize_attrs(attrs, env),
          lower_node_sequence(children, env),
          span,
        ),
      ]
  }
}

///|
fn lower_link(
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  guard children.get(0).bind(node => text_from_node(node, env~)) is Some(target) else {
    raise @model.diagnostic(span, Binding, "(link ...) requires a target")
  }
  [
    @model.RichDirective(
      @model.RichLinkDirective({
        target,
        text: rest_text(children, start=1, env~),
        span,
      }),
    ),
  ]
}

///|
fn lower_embed(
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  guard embed_target(children, env) is Some(target) else {
    raise @model.diagnostic(span, Binding, "(embed ...) requires a target")
  }
  [
    @model.RichDirective(
      @model.RichEmbedDirective({
        target,
        title: rest_text(children, start=1, env~),
        option: embed_option_from_attrs(attrs),
        span,
      }),
    ),
  ]
}

///|
fn lower_value(
  value : @core.Value,
  env : @core.CompileEnv,
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  match value {
    Scalar(s, span) => [@model.RichText(s.to_string(), span)]
    Interp(template, span) =>
      [@model.RichText(@core.interpolate_scalar(template, env, span), span)]
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
) -> Array[@model.RichContentNode] raise @core.Diagnostic {
  let env = @core.bind_template_call_env(
    template, attrs, children, call_env, call_span,
  )
  lower_node_sequence(template.body, env)
}

///|
fn normalize_attrs(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Array[@core.Attr] raise @core.Diagnostic {
  let normalized : Array[@core.Attr] = []
  for attr in attrs {
    match attr.value {
      None => normalized.push(attr)
      Some(value) =>
        normalized.push({
          name: attr.name,
          value: Some(Scalar(Text(value.to_scalar(env)), attr.span)),
          span: attr.span,
        })
    }
  }
  normalized
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
) -> @model.EmbedOption raise @core.Diagnostic {
  let mut option = @model.EmbedOption::default()
  for attr in attrs {
    let value = embed_bool_attr(attr)
    match attr.name {
      "numbering" => option = { ..option, numbering: value }
      "details-open" => option = { ..option, details_open: value }
      "catalog" => option = { ..option, catalog: value }
      _ =>
        raise @model.diagnostic(
          attr.span,
          Type,
          "unknown embed option: " + attr.name,
        )
    }
  }
  option
}

///|
fn embed_bool_attr(attr : @core.Attr) -> Bool raise @core.Diagnostic {
  match attr.value {
    Some(value) =>
      value.to_bool(
        attr.span,
        "embed option requires a boolean value: " + attr.name,
      )
    None => true
  }
}
