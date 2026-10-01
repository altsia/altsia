//! Terminal renderer for the `@cmark` event stream.
//!
//! Mirrors `terminal.mbt`'s styling decisions but walks the flat
//! `Array[@cmark.Event]` produced by the pulldown-cmark port, reusing the
//! shared math and ANSI infrastructure of this package.

///|
priv struct CommonMarkOptions {
  line_style : LineStyle
  ansi : Bool
  disable_math : Bool
  halfwidth_punct : Bool
}

///|
priv struct ListContext {
  start : Int64?
  index : Int
}

///|
/// Renders a cmark event stream as terminal text.
pub fn render_terminal_events(
  events : Array[@cmark.Event],
  line_style? : LineStyle = Unicode,
  ansi? : Bool = true,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
) -> String {
  let options = CommonMarkOptions::{
    line_style,
    ansi,
    disable_math,
    halfwidth_punct,
  }
  let out = Array()
  let mut i = 0
  while i < events.length() {
    match events[i] {
      Start(tag) => {
        let (s, next) = cm_render_block(
          events,
          i,
          tag,
          { start: None, index: 0, },
          options,
        )
        if !s.is_empty() {
          out.push(s)
        }
        i = next
      }
      Rule => {
        out.push(
          term_style("─".repeat(32), ansi=options.ansi, modifier=[
            @chalk.Modifier::Dim,
          ]),
        )
        i += 1
      }
      DisplayMath(latex) => {
        out.push(cm_render_math_display(latex, options))
        i += 1
      }
      _ => i += 1
    }
  }
  out.join("\n\n")
}

///|
fn cm_render_block(
  events : Array[@cmark.Event],
  start_ix : Int,
  tag : @cmark.Tag,
  list_ctx : ListContext,
  options : CommonMarkOptions,
) -> (String, Int) {
  match tag {
    Table(alignments) => cm_render_table(events, start_ix, alignments, options)
    List(start) => cm_render_list(events, start_ix, start, options)
    _ => cm_render_generic_block(events, start_ix, tag, list_ctx, options)
  }
}

///|
fn cm_render_generic_block(
  events : Array[@cmark.Event],
  start_ix : Int,
  tag : @cmark.Tag,
  list_ctx : ListContext,
  options : CommonMarkOptions,
) -> (String, Int) {
  let (content, blocks, task, next) = cm_collect(
    events,
    start_ix,
    options,
    cm_is_raw_text_block(tag),
  )
  (cm_assemble_block(tag, content, blocks, list_ctx, task, options), next)
}

///|
fn cm_is_raw_text_block(tag : @cmark.Tag) -> Bool {
  tag is (CodeBlock(_) | HtmlBlock | MetadataBlock(_))
}

///|
fn cm_collect(
  events : Array[@cmark.Event],
  start_ix : Int,
  options : CommonMarkOptions,
  raw_text : Bool,
) -> (Array[String], Array[String], Bool?, Int) {
  let content = Array()
  let blocks = Array()
  let mut task : Bool? = None
  let mut last_char : Char? = None
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      End(_) => break
      Start(child) => {
        let is_inline = cm_is_inline_tag(child)
        let (s, next) = if is_inline {
          cm_render_inline(events, i, child, options, prev=last_char)
        } else {
          cm_render_block(events, i, child, { start: None, index: 0, }, options)
        }
        if is_inline {
          content.push(s)
          last_char = cm_event_last_char(events, i)
        } else {
          blocks.push(s)
          last_char = None
        }
        i = next
      }
      TaskListMarker(checked) => {
        task = Some(checked)
        last_char = None
        i += 1
      }
      Text(s) => {
        let next_c = cm_next_char(events, i)
        content.push(
          if raw_text {
            s
          } else {
            cm_halfwidth_text(s, options, prev=last_char, next=next_c)
          },
        )
        last_char = if raw_text { None } else { s.iter().last() }
        i += 1
      }
      Code(s) => {
        content.push(term_style(s, ansi=options.ansi, color=@chalk.Cyan))
        last_char = None
        i += 1
      }
      InlineMath(latex) => {
        content.push(cm_render_math_inline(latex, options))
        last_char = None
        i += 1
      }
      DisplayMath(latex) => {
        blocks.push(cm_render_math_display(latex, options))
        last_char = None
        i += 1
      }
      Html(s) => {
        content.push(s)
        last_char = None
        i += 1
      }
      InlineHtml(s) => {
        content.push(s)
        last_char = None
        i += 1
      }
      FootnoteReference(s) => {
        content.push(
          term_style("[\{s}]", ansi=options.ansi, color=@chalk.Yellow),
        )
        last_char = None
        i += 1
      }
      SoftBreak => {
        content.push("\n")
        last_char = None
        i += 1
      }
      HardBreak => {
        content.push("\n")
        last_char = None
        i += 1
      }
      Rule => {
        blocks.push(
          term_style("─".repeat(32), ansi=options.ansi, modifier=[
            @chalk.Modifier::Dim,
          ]),
        )
        last_char = None
        i += 1
      }
    }
  }
  (content, blocks, task, i + 1)
}

///|
fn cm_assemble_block(
  tag : @cmark.Tag,
  content : Array[String],
  blocks : Array[String],
  list_ctx : ListContext,
  task : Bool?,
  options : CommonMarkOptions,
) -> String {
  match tag {
    Paragraph => cm_join_content_blocks(content, blocks)
    Heading(level~, ..) =>
      term_style(
        content.join(""),
        ansi=options.ansi,
        color=cm_heading_color(level),
        modifier=[@chalk.Modifier::Bold, @chalk.Modifier::Underline],
      )
    BlockQuote(_) => cm_render_blockquote(content, blocks, options)
    CodeBlock(_) =>
      term_style(
        content.join("").trim_end().to_owned(),
        ansi=options.ansi,
        color=@chalk.Cyan,
      )
    HtmlBlock => content.join("")
    Item => cm_assemble_list_item(content, blocks, list_ctx, task, options)
    FootnoteDefinition(label) =>
      "[\{label}]: \{cm_join_content_blocks(content, blocks)}"
    DefinitionList => cm_join_content_blocks(content, blocks)
    DefinitionListTitle =>
      term_style(content.join(""), ansi=options.ansi, modifier=[
        @chalk.Modifier::Bold,
      ])
    DefinitionListDefinition(_) => cm_join_content_blocks(content, blocks)
    MetadataBlock(_) => content.join("")
    ContainerBlock(_, desc) => {
      let body = cm_join_content_blocks(content, blocks)
      guard !desc.is_empty() else { body }
      term_style(desc, ansi=options.ansi, modifier=[@chalk.Modifier::Dim]) +
      "\n\n" +
      body
    }
    _ => content.join("")
  }
}

///|
fn cm_heading_color(level : @cmark.HeadingLevel) -> @chalk.Colors {
  match level {
    H1 => @chalk.Red
    H2 => @chalk.Yellow
    H3 => @chalk.Green
    _ => @chalk.White
  }
}

///|
fn cm_render_blockquote(
  content : Array[String],
  blocks : Array[String],
  options : CommonMarkOptions,
) -> String {
  let base = cm_join_content_blocks(content, blocks)
  let joined = base.split("\n").map(line => "│ \{line}").join("\n")
  term_style(joined, ansi=options.ansi, color=@chalk.WhiteBright, modifier=[
    @chalk.Modifier::Italic,
  ])
}

///|
fn cm_join_content_blocks(
  content : Array[String],
  blocks : Array[String],
) -> String {
  let inline = content.join("")
  [..if !inline.is_empty() { [inline] }, ..blocks].join("\n\n")
}

///|
fn cm_assemble_list_item(
  content : Array[String],
  blocks : Array[String],
  list_ctx : ListContext,
  task : Bool?,
  options : CommonMarkOptions,
) -> String {
  let inline = content.join("")
  let (first, children) = match blocks {
    [b, .. rest] if inline.is_empty() => (b, rest)
    _ => (inline, blocks)
  }
  let marker = cm_item_marker(list_ctx, task, options.ansi)
  let sb = StringBuilder()
  sb.write_string(marker + " " + first)
  if !children.is_empty() {
    let indented = children
      .join("\n\n")
      .split("\n")
      .map(line => "  \{line}")
      .join("\n")
    sb.write_string("\n")
    sb.write_string(indented)
  }
  sb.to_string()
}

///|
fn cm_item_marker(list_ctx : ListContext, task : Bool?, ansi : Bool) -> String {
  match task {
    Some(true) =>
      term_style("✔", ansi~, color=@chalk.Green, modifier=[
        @chalk.Modifier::Bold,
      ])
    Some(false) => term_style("○", ansi~, color=@chalk.WhiteBright)
    None =>
      match list_ctx.start {
        Some(n) => (n + list_ctx.index.to_int64()).to_string() + "."
        None => "•"
      }
  }
}

///|
fn cm_render_list(
  events : Array[@cmark.Event],
  start_ix : Int,
  start : Int64?,
  options : CommonMarkOptions,
) -> (String, Int) {
  let items = Array()
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      Start(Item) => {
        let (s, next) = cm_render_block(
          events,
          i,
          @cmark.Tag::Item,
          { start, index: items.length(), },
          options,
        )
        if !s.is_empty() {
          items.push(s)
        }
        i = next
      }
      End(_) => break
      _ => i += 1
    }
  }
  (items.join("\n"), i + 1)
}

///|
fn cm_render_table(
  events : Array[@cmark.Event],
  start_ix : Int,
  alignments : Array[@cmark.Alignment],
  options : CommonMarkOptions,
) -> (String, Int) {
  let mut header : Array[String] = Array()
  let rows : Array[Array[String]] = Array()
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      Start(TableHead) | Start(TableRow) => {
        let (cells, next) = cm_render_table_row(events, i, options)
        if header.is_empty() {
          header = cells
        } else {
          rows.push(cells)
        }
        i = next
      }
      End(_) => break
      _ => i += 1
    }
  }
  (cm_render_table_str(header, rows, alignments, options), i + 1)
}

///|
fn cm_render_table_row(
  events : Array[@cmark.Event],
  start_ix : Int,
  options : CommonMarkOptions,
) -> (Array[String], Int) {
  let cells = Array()
  let mut cell : Array[String] = Array()
  let mut last_char : Char? = None
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      Start(TableCell) => i += 1
      End(TableCell) => {
        cells.push(cell.join(""))
        cell = Array()
        last_char = None
        i += 1
      }
      End(_) => break
      Start(child) => {
        let (s, next) = cm_render_inline(
          events,
          i,
          child,
          options,
          prev=last_char,
        )
        cell.push(s)
        last_char = cm_event_last_char(events, i)
        i = next
      }
      Text(s) => {
        let next_c = cm_next_char(events, i)
        cell.push(cm_halfwidth_text(s, options, prev=last_char, next=next_c))
        last_char = s.iter().last()
        i += 1
      }
      _ => {
        cell.push(cm_render_inline_leaf(events[i], options))
        last_char = None
        i += 1
      }
    }
  }
  (cells, i + 1)
}

///|
fn cm_render_table_str(
  header : Array[String],
  rows : Array[Array[String]],
  alignments : Array[@cmark.Alignment],
  options : CommonMarkOptions,
) -> String {
  let col_count = header.length()
  let widths = table_cell_widths(header, rows, col_count)
  let h_bar = line_style_h_bar(options.line_style)
  let cross = line_style_cross(options.line_style)
  let v_bar = line_style_v_bar(options.line_style)
  let header_row = cm_render_table_row_str(
    header, widths, alignments, v_bar, options, true,
  )
  let separator = widths.map(w => h_bar.repeat(w)).join(cross)
  let body_rows = rows
    .map(r => {
      cm_render_table_row_str(r, widths, alignments, v_bar, options, false)
    })
    .join("\n")
  [header_row, separator, body_rows].join("\n")
}

///|
fn cm_render_table_row_str(
  cells : Array[String],
  widths : Array[Int],
  alignments : Array[@cmark.Alignment],
  v_bar : String,
  options : CommonMarkOptions,
  is_header : Bool,
) -> String {
  let parts = Array()
  for i in 0..<cells.length() {
    let alignment = {
      guard i < alignments.length() else { @cmark.Alignment::None }
      alignments[i]
    }
    let padded = cm_pad_cell(cells[i], widths[i], alignment)
    let styled = if is_header {
      term_style(padded, ansi=options.ansi, color=@chalk.Blue, modifier=[
        @chalk.Modifier::Bold,
      ])
    } else {
      term_style(padded, ansi=options.ansi, color=@chalk.White, modifier=[
        @chalk.Modifier::Reset,
      ])
    }
    parts.push(styled)
  }
  parts.join(" " + v_bar + " ")
}

///|
fn cm_pad_cell(
  cell : String,
  width : Int,
  alignment : @cmark.Alignment,
) -> String {
  let pad = width - cell.length()
  match alignment {
    Center => {
      let left = pad / 2
      let right = pad - left
      " ".repeat(left) + cell + " ".repeat(right)
    }
    Right => " ".repeat(pad) + cell
    _ => cell + " ".repeat(pad)
  }
}

///|
fn cm_is_inline_tag(tag : @cmark.Tag) -> Bool {
  tag
  is (Emphasis
  | Strong
  | Strikethrough
  | Highlight
  | Superscript
  | Subscript
  | Link(_)
  | Image(_))
}

///|
fn cm_render_inline(
  events : Array[@cmark.Event],
  start_ix : Int,
  tag : @cmark.Tag,
  options : CommonMarkOptions,
  prev? : Char? = None,
) -> (String, Int) {
  let content = Array()
  let mut last_char : Char? = prev
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      End(_) => break
      Start(child) => {
        let (s, next) = cm_render_inline(
          events,
          i,
          child,
          options,
          prev=last_char,
        )
        content.push(s)
        last_char = cm_event_last_char(events, i)
        i = next
      }
      Text(s) => {
        let next_c = cm_next_char(events, i)
        content.push(cm_halfwidth_text(s, options, prev=last_char, next=next_c))
        last_char = s.iter().last()
        i += 1
      }
      _ => {
        content.push(cm_render_inline_leaf(events[i], options))
        last_char = None
        i += 1
      }
    }
  }
  (cm_apply_inline_style(tag, content.join(""), options), i + 1)
}

///|
/// Index of the event right after the `End` matching the `Start` at `start_ix`.
fn cm_skip_subtree(events : Array[@cmark.Event], start_ix : Int) -> Int {
  let mut depth = 0
  let mut i = start_ix
  while i < events.length() {
    match events[i] {
      Start(_) => depth += 1
      End(_) => {
        depth -= 1
        guard depth > 0 else { return i + 1 }
      }
      _ => ()
    }
    i += 1
  }
  i
}

///|
/// The first raw text character inside the subtree starting at `start_ix`.
fn cm_subtree_first_char(events : Array[@cmark.Event], start_ix : Int) -> Char? {
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      End(_) => return None
      Text(s) => return s.iter().next()
      Start(_) => {
        guard cm_subtree_first_char(events, i) is Some(c) else {
          i = cm_skip_subtree(events, i)
          continue
        }
        return Some(c)
      }
      _ => i += 1
    }
  }
  None
}

///|
/// The last raw text character inside the subtree starting at `start_ix`.
fn cm_subtree_last_char(events : Array[@cmark.Event], start_ix : Int) -> Char? {
  let mut last : Char? = None
  let mut i = start_ix + 1
  while i < events.length() {
    match events[i] {
      End(_) => return last
      Text(s) => {
        last = s.iter().last()
        i += 1
      }
      Start(_) => {
        if cm_subtree_last_char(events, i) is Some(c) {
          last = Some(c)
        }
        i = cm_skip_subtree(events, i)
      }
      _ => i += 1
    }
  }
  last
}

///|
/// The first raw text character of the inline content starting at event `ix`.
fn cm_event_first_char(events : Array[@cmark.Event], ix : Int) -> Char? {
  guard ix < events.length() else { return None }
  match events[ix] {
    Text(s) => s.iter().next()
    Start(_) => cm_subtree_first_char(events, ix)
    _ => None
  }
}

///|
/// The last raw text character of the inline content starting at event `ix`.
fn cm_event_last_char(events : Array[@cmark.Event], ix : Int) -> Char? {
  guard ix < events.length() else { return None }
  match events[ix] {
    Text(s) => s.iter().last()
    Start(_) => cm_subtree_last_char(events, ix)
    _ => None
  }
}

///|
/// The first raw text character of the event following `ix`, if any.
fn cm_next_char(events : Array[@cmark.Event], ix : Int) -> Char? {
  guard ix + 1 < events.length() else { None }
  cm_event_first_char(events, ix + 1)
}

///|
fn cm_render_inline_leaf(
  ev : @cmark.Event,
  options : CommonMarkOptions,
) -> String {
  match ev {
    Text(s) => cm_halfwidth_text(s, options)
    Code(s) => term_style(s, ansi=options.ansi, color=@chalk.Cyan)
    InlineMath(latex) => cm_render_math_inline(latex, options)
    InlineHtml(s) => s
    Html(s) => s
    FootnoteReference(s) =>
      term_style("[\{s}]", ansi=options.ansi, color=@chalk.Yellow)
    SoftBreak => "\n"
    HardBreak => "\n"
    _ => ""
  }
}

///|
fn cm_halfwidth_text(
  s : String,
  options : CommonMarkOptions,
  prev? : Char? = None,
  next? : Char? = None,
) -> String {
  guard !options.halfwidth_punct else { to_halfwidth_punct(s, prev~, next~) }
  s
}

///|
fn cm_apply_inline_style(
  tag : @cmark.Tag,
  text : String,
  options : CommonMarkOptions,
) -> String {
  match tag {
    Emphasis =>
      term_style(text, ansi=options.ansi, modifier=[@chalk.Modifier::Italic])
    Strong =>
      term_style(text, ansi=options.ansi, modifier=[@chalk.Modifier::Bold])
    Strikethrough =>
      term_style(text, ansi=options.ansi, modifier=[
        @chalk.Modifier::Strikethrough,
      ])
    Highlight => "==" + text + "=="
    Superscript => "^{" + text + "}"
    Subscript => "_{" + text + "}"
    Link(link_type~, dest_url~, ..) =>
      match link_type {
        Autolink | Email => text
        _ => "[" + text + "](" + dest_url + ")"
      }
    Image(dest_url~, ..) =>
      term_style(
        "[img: " + text + "](" + dest_url + ")",
        ansi=options.ansi,
        color=@chalk.Yellow,
        modifier=[@chalk.Modifier::Italic],
      )
    _ => text
  }
}

///|
fn cm_render_math_inline(latex : String, options : CommonMarkOptions) -> String {
  guard !options.disable_math else { "$" + latex + "$" }
  render_math(latex, false, target=Unicode) catch {
    // need to check
    err => err.to_repr().to_string()
  }
}

///|
fn cm_render_math_display(
  latex : String,
  options : CommonMarkOptions,
) -> String {
  guard !options.disable_math else { "$$" + latex + "$$" }
  render_math(latex, true, target=Unicode) catch {
    // need to check
    err => err.to_repr().to_string()
  }
}
