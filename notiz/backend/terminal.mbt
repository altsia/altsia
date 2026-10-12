///|
/// Line style for drawn table borders.
pub(all) enum LineStyle {
  Ascii
  Unicode
} derive(Eq)

///|
pub extend LineStyle with Eq::{not_equal, equal}

///|
/// The horizontal line character for a table under the given style.
fn line_style_h_bar(style : LineStyle) -> String {
  match style {
    Ascii => "-"
    Unicode => "─"
  }
}

///|
/// The crossing line character for a table under the given style.
fn line_style_cross(style : LineStyle) -> String {
  match style {
    Ascii => "+"
    Unicode => "┼"
  }
}

///|
/// The vertical line character for a table under the given style.
fn line_style_v_bar(style : LineStyle) -> String {
  match style {
    Ascii => "|"
    Unicode => "│"
  }
}

///|
/// Rendering options threaded through every terminal render function.
pub(all) struct TerminalOptions {
  line_style : LineStyle
  ansi : Bool
  disable_math : Bool
  halfwidth_punct : Bool
}

///|
/// Apply ANSI styling to `text`, or return it unchanged when `ansi` is off.
fn term_style(
  text : String,
  ansi~ : Bool,
  color? : @chalk.Colors,
  background? : @chalk.BackGroundColors,
  modifier? : Array[@chalk.Modifier],
) -> String {
  guard ansi else { return text }
  let chalk = @chalk.chalk()
  let chalk = color.map_or(chalk, c => chalk.color(c))
  let chalk = background.map_or(chalk, b => chalk.background(b))
  let chalk = modifier.map_or(chalk, ms => {
    ms.fold(init=chalk, (c, m) => c.modifier(m))
  })
  chalk.render(text)
}

///|
pub fn render_terminal_document(
  blocks : Array[@parsing.Block],
  line_style? : LineStyle = Unicode,
  ansi? : Bool = true,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
) -> String {
  let options : TerminalOptions = {
    line_style,
    ansi,
    disable_math,
    halfwidth_punct,
  }
  blocks
  .map(b => b.term_render(options))
  .filter(s => !s.is_empty())
  .join("\n\n")
}

///|
/// Inline fragments concatenate; paragraph and block boundaries stay visible.
fn term_render_content(
  blocks : Array[@parsing.Block],
  options : TerminalOptions,
) -> String {
  let parts = Array()
  let mut after_block = false
  for block in blocks {
    let text = block.term_render(options)
    guard !text.is_empty() else { continue }
    let is_block = !block.is_inline()
    if !parts.is_empty() && (after_block || is_block) {
      parts.push("\n\n")
    }
    parts.push(text)
    after_block = is_block
  }
  parts.join("")
}

///|
/// Dispatches a block to its renderer. Add a match arm and a render
/// function here for each block variant.
fn @parsing.Block::term_render(
  self : @parsing.Block,
  options : TerminalOptions,
) -> String {
  match self {
    Heading(level, blocks, _) => term_render_heading(level, blocks, options)
    Paragraph(inlines) => term_render_inlines(inlines, options)
    UnorderedList(items) => term_render_list(items, options)
    OrderedList(items) => term_render_ordered_list(items, options)
    FencedCode(_, code) => term_render_fenced_code(code, options)
    ThematicBreak => term_render_thematic_break(options)
    DisplayMath(latex) => term_render_display_math(latex, options)
    Table(header, rows, alignments) =>
      term_render_table(header, rows, alignments, options)
    FootnoteDef(label, blocks) =>
      term_render_footnote_def(label, blocks, options)
    Text(s) => term_render_text(s, options)
    Inline(item) =>
      term_render_inline(
        item,
        options,
        convert=options.halfwidth_punct,
        prev=None,
        next=None,
      )
    Comment(_) => ""
    Element(tag, positional, named) =>
      term_render_element({ tag, positional, named, }, options)
  }
}

///|
fn term_render_heading(
  level : Int,
  blocks : Array[@parsing.Block],
  options : TerminalOptions,
) -> String {
  let color = match level {
    1 => @chalk.Red
    2 => @chalk.Yellow
    3 => @chalk.Green
    _ => @chalk.White
  }
  term_style(term_render_content(blocks, options), ansi=options.ansi, color~, modifier=[
    @chalk.Modifier::Bold,
    @chalk.Modifier::Underline,
  ])
}

///|
fn term_render_fenced_code(code : String, options : TerminalOptions) -> String {
  term_style(code.trim_end().to_owned(), ansi=options.ansi, color=@chalk.Cyan)
}

///|
fn term_render_thematic_break(options : TerminalOptions) -> String {
  term_style("─".repeat(32), ansi=options.ansi, modifier=[
    @chalk.Modifier::Dim,
  ])
}

///|
fn term_render_inline_math(latex : String, options : TerminalOptions) -> String {
  guard !options.disable_math else { "$\{latex}$" }
  render_math(latex, false, target=Unicode) catch {
    err => err.to_repr().to_string()
  }
}

///|
fn term_render_display_math(
  latex : String,
  options : TerminalOptions,
) -> String {
  guard !options.disable_math else { "$$\{latex}$$" }
  render_math(latex, true, target=Unicode) catch {
    // need to check
    err => err.to_repr().to_string()
  }
}

///|
fn term_render_footnote_def(
  label : String,
  blocks : Array[@parsing.Block],
  options : TerminalOptions,
) -> String {
  let defined = blocks.map(b => b.term_render(options)).join("\n\n")
  "[\{label}]: \{defined}"
}

///|
fn term_render_text(s : String, options : TerminalOptions) -> String {
  guard options.halfwidth_punct else { s }
  to_halfwidth_punct(s)
}

///|
fn term_render_list(
  items : Array[@parsing.MdListItem],
  options : TerminalOptions,
) -> String {
  items.map(i => term_render_list_item(i, "•", options)).join("\n")
}

///|
fn term_render_ordered_list(
  items : Array[@parsing.MdListItem],
  options : TerminalOptions,
) -> String {
  let rendered = Array()
  for i in 0..<items.length() {
    rendered.push(term_render_list_item(items[i], "\{i + 1}.", options))
  }
  rendered.join("\n")
}

///|
fn term_render_list_item(
  item : @parsing.MdListItem,
  marker : String,
  options : TerminalOptions,
) -> String {
  let marker = item.checked.map_or(marker, checked => {
    if checked {
      term_style("✔", ansi=options.ansi, color=@chalk.Green, modifier=[
        @chalk.Modifier::Bold,
      ])
    } else {
      term_style("○", ansi=options.ansi, color=@chalk.WhiteBright)
    }
  })
  let content = term_render_inlines(item.content, options)
  let children = item.children.map(b => b.term_render(options)).join("\n\n")
  let indented_children = children
    .split("\n")
    .map(line => "  \{line}")
    .join("\n")

  let result = StringBuilder()
  result <+ "\{marker} \{content}"
  if !children.is_empty() {
    result.write_string("\n")
    result <+ "\{indented_children}"
  }
  result.to_string()
}

///|
fn term_render_table(
  header : @parsing.TableRow,
  rows : Array[@parsing.TableRow],
  alignments : Array[@parsing.TableAlignment],
  options : TerminalOptions,
) -> String {
  let header_cells = header.cells.map(c => term_render_inlines(c, options))
  let body_cells = rows.map(r => {
    r.cells.map(c => term_render_inlines(c, options))
  })
  let col_count = header_cells.length()
  let widths = table_cell_widths(
    header_cells,
    body_cells,
    col_count,
    measure=term_cell_width,
  )
  let header_row = term_table_row_internal(
    header_cells,
    widths,
    alignments,
    @chalk.Blue,
    @chalk.Modifier::Bold,
    options,
  )
  let h_bar = line_style_h_bar(options.line_style)
  let cross = line_style_cross(options.line_style)
  let separator = term_style(
      widths.map(w => h_bar.repeat(w)).join(cross),
      ansi=options.ansi,
      modifier=[@chalk.Modifier::Dim],
    )
    .trim()
    .to_owned()
  let body_rows = body_cells
    .map(r => {
      term_table_row_internal(
        r,
        widths,
        alignments,
        @chalk.White,
        @chalk.Modifier::Reset,
        options,
      )
    })
    .join("\n")
  let sb = StringBuilder()
  sb <+ "\{header_row}"
  sb.write_string("\n")
  sb <+ "\{separator}"
  sb.write_string("\n")
  sb <+ "\{body_rows}"
  sb.to_string()
}

///|
fn term_table_row_internal(
  cells : Array[String],
  widths : Array[Int],
  alignments : Array[@parsing.TableAlignment],
  color : @chalk.Colors,
  modifier : @chalk.Modifier,
  options : TerminalOptions,
) -> String {
  let lines = cells.map(cell => {
    cell.split("\n").map(line => line.to_owned()).to_array()
  })
  let height = lines
    .iter()
    .fold(init=1, (height, cell) => height.max(cell.length()))
  Array::makei(height, line => {
    widths
    .mapi((i, width) => {
      let cell = lines.get(i).map_or("", lines => lines.get(line).unwrap_or(""))
      let padding = width - term_line_width(cell)
      let left = match alignments[i] {
        Left => 0
        Center => padding / 2
        Right => padding
      }
      let padded = " ".repeat(left) + cell + " ".repeat(padding - left)
      term_style(padded, ansi=options.ansi, color~, modifier=[modifier])
    })
    .join(" \{line_style_v_bar(options.line_style)} ")
  }).join("\n")
}

///|
fn term_cell_width(cell : String) -> Int {
  cell
  .split("\n")
  .fold(init=0, (width, line) => width.max(term_line_width(line.to_owned())))
}

///|
/// ANSI SGR sequences emitted by the style renderer occupy no columns.
fn term_line_width(line : String) -> Int {
  let mut styling = false
  let mut width = 0
  for c in line.iter() {
    if styling {
      if c == 'm' {
        styling = false
      }
    } else if c == '\u{1b}' {
      styling = true
    } else {
      width += @unicode.display_width(c.to_string())
    }
  }
  width
}

///|
fn term_render_inlines(
  inlines : Array[@parsing.Inline],
  options : TerminalOptions,
  prev? : Char? = None,
  next? : Char? = None,
) -> String {
  let buf = StringBuilder()
  for i in 0..<inlines.length() {
    let (prev_c, next_c) = inline_neighbors(inlines, i, prev~, next~)
    buf.write_string(
      term_render_inline(
        inlines[i],
        options,
        convert=options.halfwidth_punct,
        prev=prev_c,
        next=next_c,
      ),
    )
  }
  buf.to_string()
}

///|
fn term_render_inline(
  inline : @parsing.Inline,
  options : TerminalOptions,
  convert~ : Bool,
  prev~ : Char?,
  next~ : Char?,
) -> String {
  match inline {
    Plain(text) => {
      guard convert else { text }
      to_halfwidth_punct(text, prev~, next~)
    }
    Strong(inlines) =>
      term_style(
        term_render_inlines(inlines, options, prev~, next~),
        ansi=options.ansi,
        modifier=[@chalk.Modifier::Bold],
      )
    Emph(inlines) =>
      term_style(
        term_render_inlines(inlines, options, prev~, next~),
        ansi=options.ansi,
        modifier=[@chalk.Modifier::Italic],
      )
    Code(text) => term_style(text, ansi=options.ansi, color=@chalk.Cyan)
    Content(blocks) => term_render_content(blocks, options)
    SoftBreak => "\n"
    HardBreak => "\n"
    InlineMath(latex) => term_render_inline_math(latex, options)
    FootnoteRef(label) =>
      term_style("[\{label}]", ansi=options.ansi, color=@chalk.Yellow)
  }
}
