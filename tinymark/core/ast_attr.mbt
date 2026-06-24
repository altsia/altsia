///|
pub(all) struct Attr {
  name : String
  value : Value?
  span : SourceSpan
}

///|
pub fn Attr::optional_scalar(
  self : Attr,
  env : CompileEnv,
) -> Result[String?, Diagnostic] {
  match self.value {
    Some(value) => value.to_scalar(env).map(text => Some(text))
    None => Ok(None)
  }
}

///|
pub fn Attr::optional_literal_scalar(
  self : Attr,
  message : String,
) -> Result[String?, Diagnostic] {
  match self.value {
    Some(value) =>
      value.to_literal_scalar(self.span, message).map(text => Some(text))
    None => Ok(None)
  }
}

///|
pub fn Attr::required_scalar(
  self : Attr,
  env : CompileEnv,
  missing_message : String,
) -> Result[String, Diagnostic] {
  guard self.value is Some(value) else {
    return Err(self.span.diagnostic(DiagnosticPhase::Type, missing_message))
  }
  value.to_scalar(env)
}

///|
pub fn Attr::optional_bool(
  self : Attr,
  message : String,
) -> Result[Bool?, Diagnostic] {
  match self.value {
    Some(value) => value.to_bool(self.span, message).map(value => Some(value))
    None => Ok(None)
  }
}

///|
pub fn Attr::flag_bool(
  self : Attr,
  message : String,
) -> Result[Bool, Diagnostic] {
  match self.value {
    Some(value) => value.to_bool(self.span, message)
    None => Ok(true)
  }
}
