///|
fn diagnostic(
  span : @core.SourceSpan,
  phase : @core.DiagnosticPhase,
  message : String,
  hint? : String,
) -> @core.Diagnostic {
  match hint {
    Some(hint) => span.diagnostic(phase, message, hint~)
    None => span.diagnostic(phase, message)
  }
}

///|
fn source_span(source_id : String, message_line? : String) -> @core.SourceSpan {
  {
    source_id: Some(source_id),
    line: 1,
    column: 1,
    marker_column: 1,
    line_text: message_line.unwrap_or(""),
  }
}

///|
fn source_diagnostic(
  source_id : String,
  phase : @core.DiagnosticPhase,
  message : String,
  hint? : String,
) -> @core.Diagnostic {
  match hint {
    Some(hint) => diagnostic(source_span(source_id), phase, message, hint~)
    None => diagnostic(source_span(source_id), phase, message)
  }
}
