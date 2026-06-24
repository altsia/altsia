///|
pub fn value_to_plain_text(
  value : Value,
  env? : CompileEnv,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  value_to_plain_text_with_env(value, text_env)
}

///|
pub fn nodes_to_plain_text(
  nodes : Array[Node],
  env : CompileEnv?,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  nodes_to_plain_text_with_env(nodes, text_env)
}

///|
fn value_to_plain_text_with_env(
  value : Value,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  match value {
    Scalar(text, _) => Ok(text)
    Bool(value, _) => Ok(value.to_string())
    Interp(template, span) =>
      interpolate_text(template, env, span, value_to_plain_text_with_env)
    Fragment(nodes, _) => nodes_to_plain_text_with_env(nodes, env)
  }
}

///|
fn nodes_to_plain_text_with_env(
  nodes : Array[Node],
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  let parts : Array[String] = []
  match
    visit_scoped_nodes(nodes, env, _ => (), (node, local_env) => {
      match node {
        Text(text, _) => parts.push(text)
        TextInterp(template, span) =>
          match
            interpolate_text(
              template, local_env, span, value_to_plain_text_with_env,
            ) {
            Ok(text) => parts.push(text)
            Err(error) => return Err(error)
          }
        Ref(name, span) =>
          match plain_ref(name, local_env, span) {
            Ok(text) => parts.push(text)
            Err(error) => return Err(error)
          }
        Element(tag, attrs, children, span) =>
          match plain_element(tag, attrs, children, local_env, span) {
            Ok(text) => parts.push(text)
            Err(error) => return Err(error)
          }
        When(name, children, span) =>
          match conditional_plain_text(name, children, local_env, span, true) {
            Ok(Some(text)) => parts.push(text)
            Ok(None) => ()
            Err(error) => return Err(error)
          }
        Unless(name, children, span) =>
          match conditional_plain_text(name, children, local_env, span, false) {
            Ok(Some(text)) => parts.push(text)
            Ok(None) => ()
            Err(error) => return Err(error)
          }
        Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => ()
      }
      Ok(())
    }) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok(parts.join(""))
}

///|
fn plain_ref(
  name : String,
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  if env.lookup_value(name) is Some(value) {
    return value_to_plain_text_with_env(value, env)
  }
  if env.lookup_template(name) is Some(template) {
    return plain_template_call(template, [], [], env, span)
  }
  Err(
    span.diagnostic(
      DiagnosticPhase::Binding,
      "unbound plain text name: " + name,
    ),
  )
}

///|
fn plain_element(
  tag : String,
  attrs : Array[Attr],
  children : Array[Node],
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  match env.lookup_template(tag) {
    Some(template) => plain_template_call(template, attrs, children, env, span)
    None => nodes_to_plain_text_with_env(children, env)
  }
}

///|
fn plain_template_call(
  template : Template,
  attrs : Array[Attr],
  children : Array[Node],
  call_env : CompileEnv,
  call_span : SourceSpan,
) -> Result[String, Diagnostic] {
  bind_template_call_env(template, attrs, children, call_env, call_span).bind(template_env => {
    nodes_to_plain_text_with_env(template.body, template_env)
  })
}

///|
fn conditional_plain_text(
  name : String,
  children : Array[Node],
  env : CompileEnv,
  span : SourceSpan,
  expected : Bool,
) -> Result[String?, Diagnostic] {
  bool_binding(env, name, span).bind(value => {
    if value != expected {
      return Ok(None)
    }
    nodes_to_plain_text_with_env(children, env).map(text => Some(text))
  })
}
