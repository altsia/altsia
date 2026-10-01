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
/// Dispatches a block to its renderer. Add a match arm and a render
/// function here for each block variant.
fn @parsing.Block::term_render(
  self : @parsing.Block,
  options : TerminalOptions,
) -> String {
  match self {
    Heading(level, blocks) => term_render_heading(level, blocks, options)
    Paragraph(inlines) => term_render_inlines(inlines, options)
    UnorderedList(items) => term_render_list(items, options)
    OrderedList(items) => term_render_ordered_list(items, options)
    FencedCode(_, code) => term_render_fenced_code(code, options)
    ThematicBreak => term_render_thematic_break(options)
    DisplayMath(latex) => term_render_display_math(latex, options)
    Table(header, rows) => term_render_table(header, rows, options)
    FootnoteDef(label, blocks) =>
      term_render_footnote_def(label, blocks, options)
    Text(s) => term_render_text(s, options)
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
  term_style(
    blocks.map(b => b.term_render(options)).join(""),
    ansi=options.ansi,
    color~,
    modifier=[@chalk.Modifier::Bold, @chalk.Modifier::Underline],
  )
}

///|
fn term_render_fenced_code(code : String, options : TerminalOptions) -> String {
  term_style(
    code.trim_end().to_owned(),
    ansi=options.ansi,
    color=@chalk.Cyan,
  )
}

///|
fn term_render_thematic_break(options : TerminalOptions) -> String {
  term_style("─".repeat(32), ansi=options.ansi, modifier=[
    @chalk.Modifier::Dim,
  ])
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
  options : TerminalOptions,
) -> String {
  let header_cells = header.cells.map(c => term_render_inlines(c, options))
  let body_cells = rows.map(r => {
    r.cells.map(c => term_render_inlines(c, options))
  })
  let col_count = header_cells.length()
  let widths = table_cell_widths(header_cells, body_cells, col_count)
  let header_row = term_table_row_internal(
    header_cells,
    widths,
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
  color : @chalk.Colors,
  modifier : @chalk.Modifier,
  options : TerminalOptions,
) -> String {
  let parts = Array()
  for i in 0..<cells.length() {
    let cell = cells[i]
    let padding = String::repeat(" ", widths[i] - cell.length())
    let padded = StringBuilder()
      ..write_string(cell)
      ..write_string(padding)
      .to_string()
    let styled = term_style(padded, ansi=options.ansi, color~, modifier=[
      modifier,
    ])
    parts.push(styled)
  }
  parts.join(" \{line_style_v_bar(options.line_style)} ")
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
    Image(alt, _url) =>
      term_style(
        "[img: \{if convert { to_halfwidth_punct(alt) } else { alt }}]",
        ansi=options.ansi,
        color=@chalk.Yellow,
        modifier=[@chalk.Modifier::Italic],
      )
    SoftBreak => "\n"
    HardBreak => "\n"
    InlineMath(latex) => {
      guard !options.disable_math else { "$\{latex}$" }
      render_math(latex, false, target=Unicode) catch {
        // need to check
        err => err.to_repr().to_string()
      }
    }
    FootnoteRef(label) =>
      term_style("[\{label}]", ansi=options.ansi, color=@chalk.Yellow)
  }
}
