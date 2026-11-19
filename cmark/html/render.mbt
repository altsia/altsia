///|
/// Renders a balanced cmark event stream as an HTML fragment. Raw HTML and
/// hook output are included verbatim; this renderer does not sanitize input.
pub fn render(
  events : Array[@cmark.Event],
  hooks~ : Hooks = Hooks::new(),
) -> String {
  let out = StringBuilder()
  let table = TableState::{
    alignments: [],
    head: false,
    body: false,
    column: 0,
  }
  let mut i = 0
  while i < events.length() {
    let event = events[i]
    i += 1
    match event {
      Start(Image(dest_url~, title~, ..)) => {
        let (alt, next) = image_alt(events, i)
        out.write_string("<img")
        write_attr(out, "src", dest_url)
        write_attr(out, "alt", alt)
        write_title(out, title)
        out.write_char('>')
        i = next
      }
      Start(CodeBlock(info)) => {
        let (source, next) = read_literal(events, i)
        hooks.write_code_block(out, source, info)
        i = next
      }
      Start(HtmlBlock) => {
        let (source, next) = read_literal(events, i)
        hooks.write_raw_html(out, source, Block)
        i = next
      }
      Start(MetadataBlock(_)) =>
        while i < events.length() {
          let end = events[i] is End(MetadataBlock(_))
          i += 1
          if end {
            break
          }
        }
      Start(tag) => write_start(out, tag, table)
      End(tag) => write_end(out, tag, table)
      Text(s) => write_escaped(out, s)
      Code(s) => {
        out.write_string("<code>")
        write_escaped(out, s)
        out.write_string("</code>")
      }
      InlineMath(s) => hooks.write_math(out, s, Inline)
      DisplayMath(s) => hooks.write_math(out, s, Display)
      Html(s) => hooks.write_raw_html(out, s, Block)
      InlineHtml(s) => hooks.write_raw_html(out, s, Inline)
      FootnoteReference(label) => {
        out.write_string("<sup><a role=\"doc-noteref\"")
        write_attr(out, "href", "#\{footnote_id(label)}")
        out.write_char('>')
        write_escaped(out, label)
        out.write_string("</a></sup>")
      }
      SoftBreak => out.write_char('\n')
      HardBreak => out.write_string("<br>\n")
      Rule => out.write_string("<hr>\n")
      TaskListMarker(checked) => {
        out.write_string("<input type=\"checkbox\" disabled")
        if checked {
          out.write_string(" checked")
        }
        out.write_string("> ")
      }
    }
  }
  out.to_string()
}

///|
/// Table cells contain only inline events, so one table state suffices.
priv struct TableState {
  mut alignments : Array[@cmark.Alignment]
  mut head : Bool
  mut body : Bool
  mut column : Int32
}

///|
fn write_start(
  out : StringBuilder,
  tag : @cmark.Tag,
  table : TableState,
) -> Unit {
  match tag {
    Heading(level~, id~, classes~, attrs~) => {
      out.write_string("<\{heading_tag(level)}")
      if id is Some(id) {
        write_attr(out, "id", id)
      }
      if !classes.is_empty() {
        write_attr(out, "class", classes.join(" "))
      }
      for attr in attrs {
        let (name, value) = attr
        match name.to_lower() {
          "id" | "class" | "style" => continue
          _ => ()
        }
        guard !name.is_empty() &&
          name
          .iter()
          .all(c => {
            c.is_ascii_alphabetic() ||
            c.is_ascii_digit() ||
            c is ('-' | '_' | ':' | '.')
          }) else {
          continue
        }
        match value {
          Some(s) => write_attr(out, name, s)
          None => out.write_string(" \{name}")
        }
      }
      out.write_char('>')
    }
    BlockQuote(kind) => {
      out.write_string("<blockquote")
      if kind is Some(kind) {
        let name = match kind {
          Note => "note"
          Tip => "tip"
          Important => "important"
          Warning => "warning"
          Caution => "caution"
        }
        write_attr(out, "data-kind", name)
      }
      out.write_string(">\n")
    }
    ContainerBlock(Default, descriptor) => {
      out.write_string("<div")
      if !descriptor.is_empty() {
        write_attr(out, "data-kind", descriptor)
      }
      out.write_string(">\n")
    }
    ContainerBlock(Spoiler, summary) => {
      out.write_string("<details>\n")
      if !summary.is_empty() {
        out.write_string("<summary>")
        write_escaped(out, summary)
        out.write_string("</summary>\n")
      }
    }
    List(Some(start)) => {
      out.write_string("<ol")
      if start != 1 {
        write_attr(out, "start", start.to_string())
      }
      out.write_string(">\n")
    }
    FootnoteDefinition(label) => {
      out.write_string("<aside role=\"doc-footnote\"")
      write_attr(out, "id", footnote_id(label))
      out.write_string(">\n")
    }
    Table(alignments) => {
      table.alignments = alignments
      table.body = false
      out.write_string("<table>\n")
    }
    TableHead => {
      table.head = true
      table.column = 0
      out.write_string("<thead>\n<tr>")
    }
    TableRow => {
      if !table.body {
        out.write_string("<tbody>\n")
        table.body = true
      }
      table.column = 0
      out.write_string("<tr>")
    }
    TableCell => {
      out.write_string(if table.head { "<th" } else { "<td" })
      match table.alignments.get(table.column) {
        Some(Left) => write_attr(out, "data-align", "left")
        Some(Center) => write_attr(out, "data-align", "center")
        Some(Right) => write_attr(out, "data-align", "right")
        _ => ()
      }
      table.column += 1
      out.write_char('>')
    }
    Link(dest_url~, title~, ..) => {
      out.write_string("<a")
      write_attr(out, "href", dest_url)
      write_title(out, title)
      out.write_char('>')
    }
    Paragraph => out.write_string("<p>")
    List(None) => out.write_string("<ul>\n")
    Item => out.write_string("<li>")
    DefinitionList => out.write_string("<dl>\n")
    DefinitionListTitle => out.write_string("<dt>")
    DefinitionListDefinition => out.write_string("<dd>")
    Emphasis => out.write_string("<em>")
    Strong => out.write_string("<strong>")
    Strikethrough => out.write_string("<del>")
    CodeBlock(_) | HtmlBlock | Image(..) | MetadataBlock(_) => ()
  }
}

///|
fn write_end(
  out : StringBuilder,
  tag : @cmark.TagEnd,
  table : TableState,
) -> Unit {
  out.write_string(
    match tag {
      Paragraph => "</p>\n"
      Heading(level) => "</\{heading_tag(level)}>\n"
      BlockQuote(_) => "</blockquote>\n"
      ContainerBlock(Default) => "</div>\n"
      ContainerBlock(Spoiler) => "</details>\n"
      List(true) => "</ol>\n"
      List(false) => "</ul>\n"
      Item => "</li>\n"
      FootnoteDefinition => "</aside>\n"
      DefinitionList => "</dl>\n"
      DefinitionListTitle => "</dt>\n"
      DefinitionListDefinition => "</dd>\n"
      Table => if table.body { "</tbody>\n</table>\n" } else { "</table>\n" }
      TableHead => {
        table.head = false
        "</tr>\n</thead>\n"
      }
      TableRow => "</tr>\n"
      TableCell => if table.head { "</th>" } else { "</td>" }
      Emphasis => "</em>"
      Strong => "</strong>"
      Strikethrough => "</del>"
      Link => "</a>"
      CodeBlock | HtmlBlock | Image | MetadataBlock(_) => ""
    },
  )
}

///|
fn read_literal(events : Array[@cmark.Event], start : Int32) -> (String, Int32) {
  let out = StringBuilder()
  let mut i = start
  while i < events.length() {
    let event = events[i]
    i += 1
    match event {
      End(CodeBlock | HtmlBlock) => break
      Text(s) | Html(s) => out.write_string(s)
      _ => ()
    }
  }
  (out.to_string(), i)
}

///|
fn image_alt(events : Array[@cmark.Event], start : Int32) -> (String, Int32) {
  let out = StringBuilder()
  let mut depth = 1
  let mut i = start
  while i < events.length() && depth > 0 {
    match events[i] {
      Start(Image(..)) => depth += 1
      End(Image) => depth -= 1
      Text(s)
      | Code(s)
      | InlineMath(s)
      | DisplayMath(s)
      | FootnoteReference(s) => out.write_string(s)
      SoftBreak | HardBreak => out.write_char(' ')
      _ => ()
    }
    i += 1
  }
  (out.to_string(), i)
}

///|
fn heading_tag(level : @cmark.HeadingLevel) -> String {
  match level {
    H1 => "h1"
    H2 => "h2"
    H3 => "h3"
    H4 => "h4"
    H5 => "h5"
    H6 => "h6"
  }
}

///|
fn write_title(out : StringBuilder, title : String) -> Unit {
  if !title.is_empty() {
    write_attr(out, "title", title)
  }
}

///|
fn write_attr(out : StringBuilder, name : String, value : String) -> Unit {
  out.write_string(" \{name}=\"")
  write_escaped(out, value, attribute=true)
  out.write_char('"')
}

///|
fn write_escaped(
  out : StringBuilder,
  text : String,
  attribute~ : Bool = false,
) -> Unit {
  for c in text {
    match c {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' if attribute => out.write_string("&quot;")
      _ => out.write_char(c)
    }
  }
}

///|
/// Restrict the id to fragment-safe characters without conflating labels.
fn footnote_id(label : String) -> String {
  let out = StringBuilder()
  out.write_string("fn-")
  for c in label {
    if c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-' {
      out.write_char(c)
    } else {
      out.write_string("_\{c.to_int().to_string(radix=16)}_")
    }
  }
  out.to_string()
}
