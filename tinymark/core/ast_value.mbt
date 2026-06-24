///|
pub(all) enum Value {
  Scalar(String, SourceSpan)
  Bool(Bool, SourceSpan)
  Fragment(Array[Node], SourceSpan)
  Interp(Interpolation, SourceSpan)
}

///|
pub fn Value::span(self : Value) -> SourceSpan {
  match self {
    Scalar(_, span) | Bool(_, span) | Fragment(_, span) | Interp(_, span) =>
      span
  }
}

///|
pub fn Value::to_scalar(
  self : Value,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  match self {
    Scalar(text, _) => Ok(text)
    Bool(value, _) => Ok(if value { "true" } else { "false" })
    Interp(template, span) => interpolate_scalar(template, env, span)
    Fragment(_, span) =>
      Err(
        span.diagnostic(
          DiagnosticPhase::Type,
          "expected scalar value, but got rich content",
        ),
      )
  }
}

///|
pub fn Value::to_literal_scalar(
  self : Value,
  context_span : SourceSpan,
  message : String,
) -> Result[String, Diagnostic] {
  match self {
    Scalar(text, _) => Ok(text)
    Bool(value, _) => Ok(if value { "true" } else { "false" })
    _ => Err(context_span.diagnostic(DiagnosticPhase::Type, message))
  }
}
