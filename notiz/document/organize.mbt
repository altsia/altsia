///|
/// A document always groups text into paragraphs. Content fragments omit a
/// paragraph wrapper when they contain only inline content. Headings and
/// emphasis preserve whitespace inside their own inline content.
priv enum Scope {
  Document
  Fragment
  UntrimmedFragment
}

///|
priv enum Part {
  Item(Node)
  Break
}

///|
/// Organize a parsed document once, recursively, before choosing a backend.
pub fn organize(content : Array[@parsing.Content]) -> Array[Node] {
  organize_scope(content, Document)
}

///|
fn organize_scope(
  content : Array[@parsing.Content],
  scope : Scope,
) -> Array[Node] {
  let parts = Array()
  content.each(item => expand(item, parts))
  let has_boundary = parts.any(part => {
    match part {
      Break => true
      Item(node) => !node.is_inline()
    }
  })
  if !(scope is Document) && !has_boundary {
    let nodes = parts.filter_map(part => {
      guard part is Item(node) else { return None }
      Some(node)
    })
    let nodes = if scope is UntrimmedFragment {
      nodes
    } else {
      trim_text(nodes)
    }
    return if nodes.is_empty() { [] } else { [InlineRun(nodes)] }
  }
  let output = Array()
  let pending = Array()
  for part in parts {
    match part {
      Item(node) if node.is_inline() => pending.push(node)
      Item(node) => {
        finish_paragraph(pending, output)
        output.push(node)
      }
      Break => finish_paragraph(pending, output)
    }
  }
  finish_paragraph(pending, output)
  output
}

///|
/// Spliced sequences are traversed in the surrounding flow, so they cannot
/// introduce accidental paragraph boundaries around their individual items.
fn expand(content : @parsing.Content, parts : Array[Part]) -> Unit {
  let node : Node = match content {
    Sequence(items) => {
      items.each(item => expand(item, parts))
      return
    }
    ParagraphBreak => {
      parts.push(Break)
      return
    }
    Text(text) => Text(text)
    Strong(items) => Strong(organize_scope(items, UntrimmedFragment))
    Emph(items) => Emph(organize_scope(items, UntrimmedFragment))
    Code(text) => Code(text)
    SoftBreak => SoftBreak
    HardBreak => HardBreak
    InlineMath(source) => InlineMath(source)
    FootnoteRef(label) => FootnoteRef(label)
    Comment(text) => Comment(text)
    Heading(level, items, attributes) =>
      Heading(
        level,
        organize_scope(items, UntrimmedFragment),
        organize_named(attributes),
      )
    UnorderedList(items) => UnorderedList(items.map(organize_list_item))
    OrderedList(items) => OrderedList(items.map(organize_list_item))
    FencedCode(language, text) => FencedCode(language, text)
    DisplayMath(source) => DisplayMath(source)
    ThematicBreak => ThematicBreak
    Table(header, rows, alignments) =>
      Table(organize_row(header), rows.map(organize_row), alignments)
    FootnoteDef(label, items) =>
      FootnoteDef(label, organize_scope(items, Document))
    Element(tag, positional, named) => {
      let content = positional
        .filter_map(value => {
          guard value is Content(items) else { return None }
          Some(items)
        })
        .flatten()
      Element({
        tag,
        positional: positional.filter_map(value => {
          guard !(value is Content(_)) else { return None }
          Some(organize_value(value))
        }),
        named: organize_named(named),
        content: organize_scope(content, Fragment),
      })
    }
  }
  parts.push(Item(node))
}

///|
fn organize_value(value : @parsing.Value) -> Value {
  match value {
    Text(text) => Text(text)
    Integer(value) => Integer(value)
    Content(items) => Content(organize_scope(items, Fragment))
    Call(_, _, _) => Call(organize_scope(@parsing.flow_of(value), Fragment))
    Comment(text) => Comment(text)
  }
}

///|
fn organize_named(values : Map[String, @parsing.Value]) -> Map[String, Value] {
  Map(values.iter().map(pair => (pair.0, organize_value(pair.1))).to_array())
}

///|
fn organize_list_item(item : @parsing.MdListItem) -> ListItem {
  {
    checked: item.checked,
    content: organize_scope(item.content, Fragment),
    children: organize_scope(item.children, Document),
  }
}

///|
fn organize_row(row : @parsing.TableRow) -> TableRow {
  { cells: row.cells.map(items => organize_scope(items, Fragment)), }
}

///|
fn finish_paragraph(pending : Array[Node], output : Array[Node]) -> Unit {
  let nodes = trim_text(pending)
  if !nodes.is_empty() {
    output.push(Paragraph(nodes))
  }
  pending.clear()
}

///|
/// Trim only plain text at flow boundaries; code, math, hard breaks and
/// whitespace explicitly enclosed in emphasis retain their contents.
fn trim_text(items : Array[Node]) -> Array[Node] {
  let start = for i = 0; i < items.length(); {
    match items[i] {
      SoftBreak => continue i + 1
      Text(text) if text.trim().is_empty() => continue i + 1
      _ => break i
    }
  } nobreak {
    items.length()
  }
  let end = for i = items.length(); i > start; {
    match items[i - 1] {
      SoftBreak => continue i - 1
      Text(text) if text.trim().is_empty() => continue i - 1
      _ => break i
    }
  } nobreak {
    start
  }
  let trimmed = items[start:end].to_owned()
  if trimmed.get(0) is Some(Text(text)) {
    trimmed[0] = Text(text.trim_start().to_owned())
  }
  if trimmed.last() is Some(Text(text)) {
    trimmed[trimmed.length() - 1] = Text(text.trim_end().to_owned())
  }
  trimmed
}
