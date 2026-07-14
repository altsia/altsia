///|
pub(all) enum Value {
  Scalar(Scalar, SourceSpan)
  Fragment(Fragment, SourceSpan)
  Interp(Interpolation, SourceSpan)
}

///|
pub(all) enum Scalar {
  Text(String)
  Bool(Bool)
}

///|
pub fn Value::span(self : Value) -> SourceSpan {
  match self {
    Scalar(_, span) | Fragment(_, span) | Interp(_, span) => span
  }
}

///|
pub fn Value::to_scalar(
  self : Value,
  env : CompileEnv,
) -> String raise Diagnostic {
  match self {
    Scalar(scalar, _) => scalar.to_string()
    Interp(template, span) => interpolate_scalar(template, env, span)
    Fragment(_, span) =>
      raise span.diagnostic(
        DiagnosticPhase::Type,
        "expected scalar value, but got rich content",
      )
  }
}

///|
pub fn Value::to_literal_scalar(
  self : Value,
  context_span : SourceSpan,
  message : String,
) -> String raise Diagnostic {
  match self {
    Scalar(scalar, _) => scalar.to_string()
    _ => raise context_span.diagnostic(DiagnosticPhase::Type, message)
  }
}

///|
pub fn Scalar::to_string(self : Scalar) -> String {
  match self {
    Text(text) => text
    Bool(value) => if value { "true" } else { "false" }
  }
}
