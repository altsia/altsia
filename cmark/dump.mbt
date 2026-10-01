//! Canonical event dump used as the unit-test oracle.
//!
//! The output format is a line-per-event canonical dump.

///|
/// Parses `source` and returns a line-per-event canonical dump.
pub fn event_dump(source : String, options : Options) -> String {
  let events = parse(source, options)
  let parts = events.map(dump_event)
  parts.join("\n")
}

///|
fn dump_escape(s : String) -> String {
  let bytes = @utf8.encode(s)
  let buf = @buffer.Buffer(size_hint=bytes.length())
  for i in 0..<bytes.length() {
    let b = bytes.unsafe_get(i)
    match b.to_int() {
      0x5c => buf.write_bytesview(b"\\\\".exact_view())
      0x0a => buf.write_bytesview(b"\\n".exact_view())
      0x0d => buf.write_bytesview(b"\\r".exact_view())
      0x09 => buf.write_bytesview(b"\\t".exact_view())
      0x7c => buf.write_bytesview(b"\\|".exact_view())
      _ => buf.write_byte(b)
    }
  }
  @utf8.decode_lossy(buf.to_bytes().exact_view())
}

///|
fn dump_event(ev : Event) -> String {
  match ev {
    Start(tag) => dump_tag(tag)
    End(tag_end) => dump_tag_end(tag_end)
    Text(s) => "Text|" + dump_escape(s)
    Code(s) => "Code|" + dump_escape(s)
    InlineMath(s) => "InlineMath|" + dump_escape(s)
    DisplayMath(s) => "DisplayMath|" + dump_escape(s)
    Html(s) => "Html|" + dump_escape(s)
    InlineHtml(s) => "InlineHtml|" + dump_escape(s)
    FootnoteReference(s) => "FootnoteReference|" + dump_escape(s)
    SoftBreak => "SoftBreak"
    HardBreak => "HardBreak"
    Rule => "Rule"
    TaskListMarker(b) => "TaskListMarker|" + b.to_string()
  }
}

///|
fn dump_tag(tag : Tag) -> String {
  match tag {
    Paragraph => "Start|Paragraph"
    Heading(level~, id~, classes~, attrs~) =>
      "Start|Heading|" +
      level_str(level) +
      "|" +
      id.map_or("None", s => "Some(" + dump_escape(s) + ")") +
      "|" +
      classes.map(dump_escape).join(",") +
      "|" +
      join_attrs(attrs)
    BlockQuote(kind) => "Start|BlockQuote|" + blockquote_str(kind)
    CodeBlock(kind) => "Start|CodeBlock|" + codeblock_str(kind)
    ContainerBlock(kind, d) =>
      "Start|ContainerBlock|" + container_str(kind) + "|" + dump_escape(d)
    HtmlBlock => "Start|HtmlBlock"
    List(start) => "Start|List|" + list_str(start)
    Item => "Start|Item"
    FootnoteDefinition(s) => "Start|FootnoteDefinition|" + dump_escape(s)
    DefinitionList => "Start|DefinitionList"
    DefinitionListTitle => "Start|DefinitionListTitle"
    DefinitionListDefinition => "Start|DefinitionListDefinition"
    Table(a) => "Start|Table|" + join_alignments(a)
    TableHead => "Start|TableHead"
    TableRow => "Start|TableRow"
    TableCell => "Start|TableCell"
    Emphasis => "Start|Emphasis"
    Strong => "Start|Strong"
    Strikethrough => "Start|Strikethrough"
    Highlight => "Start|Highlight"
    Superscript => "Start|Superscript"
    Subscript => "Start|Subscript"
    Link(link_type~, dest_url~, title~, id~) =>
      "Start|Link|" +
      linktype_str(link_type) +
      "|" +
      dump_escape(dest_url) +
      "|" +
      dump_escape(title) +
      "|" +
      dump_escape(id)
    Image(link_type~, dest_url~, title~, id~) =>
      "Start|Image|" +
      linktype_str(link_type) +
      "|" +
      dump_escape(dest_url) +
      "|" +
      dump_escape(title) +
      "|" +
      dump_escape(id)
    MetadataBlock(kind) => "Start|MetadataBlock|" + metadata_str(kind)
  }
}

///|
fn dump_tag_end(te : TagEnd) -> String {
  match te {
    Paragraph => "End|Paragraph"
    Heading(level) => "End|Heading|" + level_str(level)
    BlockQuote(kind) => "End|BlockQuote|" + blockquote_str(kind)
    CodeBlock => "End|CodeBlock"
    ContainerBlock(kind) => "End|ContainerBlock|" + container_str(kind)
    HtmlBlock => "End|HtmlBlock"
    List(b) => "End|List|" + b.to_string()
    Item => "End|Item"
    FootnoteDefinition => "End|FootnoteDefinition"
    DefinitionList => "End|DefinitionList"
    DefinitionListTitle => "End|DefinitionListTitle"
    DefinitionListDefinition => "End|DefinitionListDefinition"
    Table => "End|Table"
    TableHead => "End|TableHead"
    TableRow => "End|TableRow"
    TableCell => "End|TableCell"
    Emphasis => "End|Emphasis"
    Strong => "End|Strong"
    Strikethrough => "End|Strikethrough"
    Highlight => "End|Highlight"
    Superscript => "End|Superscript"
    Subscript => "End|Subscript"
    Link => "End|Link"
    Image => "End|Image"
    MetadataBlock(kind) => "End|MetadataBlock|" + metadata_str(kind)
  }
}

///|
fn level_str(level : HeadingLevel) -> String {
  match level {
    H1 => "H1"
    H2 => "H2"
    H3 => "H3"
    H4 => "H4"
    H5 => "H5"
    H6 => "H6"
  }
}

///|
fn join_attrs(items : Array[(String, String?)]) -> String {
  let parts = items.map(p => {
    match p {
      (k, Some(v)) => dump_escape(k) + "=" + dump_escape(v)
      (k, None) => dump_escape(k)
    }
  })
  parts.join(",")
}

///|
fn join_alignments(items : Array[Alignment]) -> String {
  let parts = items.map(a => {
    match a {
      None => "None"
      Left => "Left"
      Center => "Center"
      Right => "Right"
    }
  })
  parts.join(",")
}

///|
fn list_str(o : Int64?) -> String {
  match o {
    Some(n) => "Some(" + n.to_string() + ")"
    None => "None"
  }
}

///|
fn blockquote_str(kind : BlockQuoteKind?) -> String {
  match kind {
    None => "None"
    Some(Note) => "Note"
    Some(Tip) => "Tip"
    Some(Important) => "Important"
    Some(Warning) => "Warning"
    Some(Caution) => "Caution"
  }
}

///|
fn container_str(kind : ContainerKind) -> String {
  match kind {
    Default => "Default"
    Spoiler => "Spoiler"
  }
}

///|
fn metadata_str(kind : MetadataBlockKind) -> String {
  match kind {
    YamlStyle => "YamlStyle"
    PlusesStyle => "PlusesStyle"
  }
}

///|
fn codeblock_str(kind : CodeBlockKind) -> String {
  match kind {
    Indented => "Indented"
    Fenced(lang) => "Fenced(" + dump_escape(lang) + ")"
  }
}

///|
fn linktype_str(lt : LinkType) -> String {
  match lt {
    Inline => "Inline"
    Reference => "Reference"
    ReferenceUnknown => "ReferenceUnknown"
    Collapsed => "Collapsed"
    CollapsedUnknown => "CollapsedUnknown"
    Shortcut => "Shortcut"
    ShortcutUnknown => "ShortcutUnknown"
    Autolink => "Autolink"
    Email => "Email"
    WikiLink(b) => "WikiLink(" + b.to_string() + ")"
  }
}
