///|
pub(all) enum InterpolationPart {
  Literal(String)
  Name(String)
} derive(Eq, Debug)

///|
pub type Interpolation = Array[InterpolationPart]

///|
pub(all) enum Node {
  Text(String, SourceSpan)
  TextInterp(Interpolation, SourceSpan)
  Element(String, Array[Attr], Array[Node], SourceSpan)
  Ref(String, SourceSpan)
  Let(String, Value, SourceSpan)
  Def(String, Array[String], Array[Node], SourceSpan)
  Doc(Array[Attr], SourceSpan)
  When(String, Array[Node], SourceSpan)
  Unless(String, Array[Node], SourceSpan)
}

///|
pub type Fragment = Array[Node]

///|
pub(all) struct Attr {
  name : String
  value : Value?
  span : SourceSpan
}

///|
pub(all) struct SourceInfo {
  id : String?
  line_offset : Int
  column_offset : Int
}

///|
pub(all) struct SourceSpan {
  source_id : String?
  line : Int
  column : Int
  marker_column : Int
  line_text : String
}

///|
pub(all) struct Document {
  source : SourceInfo
  nodes : Array[Node]
}

///|
pub(all) enum DiagnosticPhase {
  Syntax
  Template
  Binding
  Type
  ContentModel
  Placement
}

///|
pub(all) struct Diagnostic {
  phase : DiagnosticPhase
  message : String
  span : SourceSpan
  hint : String?
}

///|
pub fn SourceSpan::diagnostic(
  self : SourceSpan,
  phase : DiagnosticPhase,
  message : String,
  hint? : String,
) -> Diagnostic {
  { phase, message, span: self, hint }
}

///|
pub fn Node::span(self : Node) -> SourceSpan {
  match self {
    Text(_, span)
    | TextInterp(_, span)
    | Element(_, _, _, span)
    | Ref(_, span)
    | Let(_, _, span)
    | Def(_, _, _, span)
    | Doc(_, span)
    | When(_, _, span)
    | Unless(_, _, span) => span
  }
}

///|
pub fn Diagnostic::render(self : Diagnostic) -> String {
  let span = self.span
  let location = match span.source_id {
    Some(source_id) =>
      source_id + ":" + span.line.to_string() + ":" + span.column.to_string()
    None =>
      "line " + span.line.to_string() + ", column " + span.column.to_string()
  }
  let rendered = self.phase.label() +
    " error at " +
    location +
    ": " +
    self.message +
    "\n" +
    span.line.to_string() +
    " | " +
    span.line_text +
    "\n" +
    repeat_string(" ", span.line.to_string().length()) +
    " | " +
    repeat_string(" ", span.marker_column - 1) +
    "^"
  match self.hint {
    Some(hint) => rendered + "\nhint: " + hint
    None => rendered
  }
}

///|
fn repeat_string(text : String, count : Int) -> String {
  let builder = StringBuilder()
  for _ in 0..<count {
    builder.write_string(text)
  }
  builder.to_string()
}

///|
pub fn SourceInfo::default() -> SourceInfo {
  { id: None, line_offset: 0, column_offset: 0 }
}

///|
fn DiagnosticPhase::label(self : DiagnosticPhase) -> String {
  match self {
    Syntax => "syntax"
    Template => "template"
    Binding => "binding"
    Type => "type"
    ContentModel => "content model"
    Placement => "placement"
  }
}
