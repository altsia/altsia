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
pub fn Value::unsafe_primitive(self : Value) -> String {
  match self {
    Scalar(text, _) => text
    Bool(value, _) => if value { "true" } else { "false" }
    _ => abort("unreachable")
  }
}

///|
pub fn Value::to_scalar(
  self : Value,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  match self {
    Scalar(_) | Bool(_) => Ok(self.unsafe_primitive())
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
    Scalar(_) | Bool(_) => Ok(self.unsafe_primitive())
    _ => Err(context_span.diagnostic(DiagnosticPhase::Type, message))
  }
}
