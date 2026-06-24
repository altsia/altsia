///|
priv suberror PlainTextError {
  Diagnostic(Diagnostic)
}

///|
pub fn value_to_plain_text(
  value : Value,
  env? : CompileEnv,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  plain_text_result(() => value_to_plain_text_with_env(value, text_env))
}

///|
pub fn nodes_to_plain_text(
  nodes : Array[Node],
  env : CompileEnv?,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  plain_text_result(() => nodes_to_plain_text_with_env(nodes, text_env))
}

///|
fn plain_text_result(
  f : () -> String raise PlainTextError,
) -> Result[String, Diagnostic] {
  Ok(f()) catch {
    PlainTextError::Diagnostic(diagnostic) => Err(diagnostic)
  }
}

///|
fn[T] raise_diagnostic(
  result : Result[T, Diagnostic],
) -> T raise PlainTextError {
  match result {
    Ok(value) => value
    Err(diagnostic) => raise PlainTextError::Diagnostic(diagnostic)
  }
}

///|
fn value_to_plain_text_with_env(
  value : Value,
  env : CompileEnv,
) -> String raise PlainTextError {
  match value {
    Scalar(text, _) => text
    Bool(value, _) => value.to_string()
    Interp(template, span) => plain_interpolate_text(template, env, span)
    Fragment(nodes, _) => nodes_to_plain_text_with_env(nodes, env)
  }
}

///|
fn nodes_to_plain_text_with_env(
  nodes : Array[Node],
  env : CompileEnv,
) -> String raise PlainTextError {
  let parts : Array[String] = []
  ignore(
    visit_scoped_nodes_raise(nodes, env, _ => (), (node, local_env) => {
      match node {
        Text(text, _) => parts.push(text)
        TextInterp(template, span) =>
          parts.push(plain_interpolate_text(template, local_env, span))
        Ref(name, span) => parts.push(plain_ref(name, local_env, span))
        Element(tag, attrs, children, span) =>
          parts.push(plain_element(tag, attrs, children, local_env, span))
        When(name, children, span) =>
          if conditional_plain_text(name, children, local_env, span, true)
            is Some(text) {
            parts.push(text)
          }
        Unless(name, children, span) =>
          if conditional_plain_text(name, children, local_env, span, false)
            is Some(text) {
            parts.push(text)
          }
        Let(_, _, _) | Def(_, _, _, _) | Doc(_, _) => ()
      }
    }),
  )
  parts.join("")
}

///|
fn visit_scoped_nodes_raise(
  nodes : Array[Node],
  env : CompileEnv,
  on_doc_attr : (Attr) -> Unit,
  visit : (Node, CompileEnv) -> Unit raise PlainTextError,
) -> CompileEnv raise PlainTextError {
  let local_env = collect_scope_env(nodes, env)
  for node in nodes {
    if !local_env.bind_scope_node(node, on_doc_attr) {
      visit(node, local_env)
    }
  }
  local_env
}

///|
fn plain_interpolate_text(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
) -> String raise PlainTextError {
  let parts : Array[String] = []
  for part in template {
    match part {
      Literal(text) => parts.push(text)
      Name(name) => {
        guard env.lookup_value(name) is Some(value) else {
          raise PlainTextError::Diagnostic(
            span.diagnostic(
              DiagnosticPhase::Binding,
              "unbound interpolation name: " + name,
            ),
          )
        }
        parts.push(value_to_plain_text_with_env(value, env))
      }
    }
  }
  parts.join("")
}

///|
fn plain_ref(
  name : String,
  env : CompileEnv,
  span : SourceSpan,
) -> String raise PlainTextError {
  if env.lookup_value(name) is Some(value) {
    return value_to_plain_text_with_env(value, env)
  }
  if env.lookup_template(name) is Some(template) {
    return plain_template_call(template, [], [], env, span)
  }
  raise PlainTextError::Diagnostic(
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
) -> String raise PlainTextError {
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
) -> String raise PlainTextError {
  let template_env = raise_diagnostic(
    bind_template_call_env(template, attrs, children, call_env, call_span),
  )
  nodes_to_plain_text_with_env(template.body, template_env)
}

///|
fn conditional_plain_text(
  name : String,
  children : Array[Node],
  env : CompileEnv,
  span : SourceSpan,
  expected : Bool,
) -> String? raise PlainTextError {
  let value = raise_diagnostic(bool_binding(env, name, span))
  guard value == expected else { return None }
  Some(nodes_to_plain_text_with_env(children, env))
}
