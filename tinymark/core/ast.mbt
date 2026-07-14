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
pub(all) suberror Diagnostic {
  Diagnostic(
    phase~ : DiagnosticPhase,
    message~ : String,
    span~ : SourceSpan,
    hint~ : String?
  )
}

///|
pub fn SourceSpan::diagnostic(
  self : SourceSpan,
  phase : DiagnosticPhase,
  message : String,
  hint? : String,
) -> Diagnostic {
  Diagnostic(phase~, message~, span=self, hint~)
}

///|
pub fn Diagnostic::phase(self : Diagnostic) -> DiagnosticPhase {
  let Diagnostic(phase~, ..) = self
  phase
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  let Diagnostic(message~, ..) = self
  message
}

///|
pub fn Diagnostic::span(self : Diagnostic) -> SourceSpan {
  let Diagnostic(span~, ..) = self
  span
}

///|
pub fn Diagnostic::hint(self : Diagnostic) -> String? {
  let Diagnostic(hint~, ..) = self
  hint
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
  let Diagnostic(phase~, message~, span~, hint~) = self

  let location = span.source_id.map_or_else(
    () => "line \{span.line}, column \{span.column}",
    source_id => "\{source_id}:\{span.line}:\{span.column}",
  )

  let rendered = StringBuilder()
  rendered <+ "\{phase.label()} error at \{location}: \{message}\n"
  rendered <+ "\{span.line.to_string()} | \{span.line_text}\n"
  rendered <+ "\{repeat_string(" ", span.line.to_string().length())} | "
  rendered <+ "\{repeat_string(" ", span.marker_column - 1)}^"

  hint.map_or_else(() => rendered.to_string(), hint => {
    (rendered <+ "\nhint: \{hint}").to_string()
  })
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
