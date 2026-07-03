///|
pub fn value_to_plain_text(
  value : Value,
  env? : CompileEnv,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  compile_backend_value(value, text_env, 1, plain_text_backend(), []).bind(
    plain_output_to_text,
  )
}

///|
pub fn nodes_to_plain_text(
  nodes : Array[Node],
  env : CompileEnv?,
) -> Result[String, Diagnostic] {
  let text_env = env.unwrap_or(CompileEnv::empty())
  compile_backend_nodes_output(
    nodes,
    text_env,
    1,
    false,
    plain_text_backend(),
    [],
  ).bind(plain_output_to_text)
}

///|
fn plain_text_backend() -> RenderBackend[String, Unit] {
  {
    text: text => text,
    interpolate_text: plain_interpolate_text,
    append_inline_node: (inline_run, _, node) => inline_run.push(node),
    flush_inline_run: (inline_run, out) => {
      out.append(inline_run.copy())
      inline_run.clear()
    },
    output_text: text => Some(text),
    resolve_element: plain_element_resolver,
  }
}

///|
fn plain_output_to_text(
  output : BackendOutput[String, Unit],
) -> Result[String, Diagnostic] {
  Ok(output.body.join(""))
}

///|
fn plain_element_resolver(
  compiler : BackendCallContext[String, Unit],
) -> Result[BackendOutput[String, Unit]?, Diagnostic] {
  let call = compiler.call
  match call.source {
    RefElement =>
      Err(call.span.diagnostic(Binding, "unbound plain text name: " + call.tag))
    ExplicitElement =>
      (compiler.context.compile_inline)(call.children).map(output => {
        Some(output)
      })
  }
}

///|
fn plain_interpolate_text(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  interpolate_text(template, env, span, (value, value_env) => {
    value_to_plain_text(value, env=value_env)
  })
}
