///|
/// Rendering options threaded through every HTML render function.
pub(all) struct HtmlOptions {
  target : KatexTarget
  disable_math : Bool
  halfwidth_punct : Bool
}

///|
pub fn render_document(
  blocks : Array[@parsing.Block],
  target~ : KatexTarget,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
) -> String {
  let options = { target, disable_math, halfwidth_punct, }
  join_blocks(blocks, options) |> render_nodes
}

///|
/// The document title for the HTML `<title>` element: the frontmatter
/// `title` when set, otherwise the plain-text rendering of the first
/// top-level `=` heading. Empty when neither exists.
///
/// The heading is rendered with the terminal backend (ANSI off) so that
/// rich content such as emphasis or math degrades to a readable
/// plain-text form instead of raw markup.
pub fn page_title(
  frontmatter : @parsing.Frontmatter,
  blocks : Array[@parsing.Block],
) -> String {
  let title = frontmatter.builtin.title
  guard title.is_empty() else { title }
  for block in blocks {
    guard block is Heading(1, blocks) else { continue }
    return render_terminal_document(
      [Heading(1, blocks)],
      line_style=Unicode,
      ansi=false,
      disable_math=false,
      halfwidth_punct=false,
    )
  }
  ""
}

///|
pub fn render_document_page(
  blocks : Array[@parsing.Block],
  frontmatter : @parsing.Frontmatter,
  paper~ : @parsing.Paper,
  target~ : KatexTarget,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
  head_extra? : String = "",
) -> String {
  render_page(
    render_document(blocks, target~, disable_math~, halfwidth_punct~),
    frontmatter,
    paper~,
    head_extra~,
  )
}

///|
pub fn render_page(
  content : String,
  frontmatter : @parsing.Frontmatter,
  paper~ : @parsing.Paper,
  head_extra? : String = "",
) -> String {
  let lang = frontmatter.builtin.lang
  let title = frontmatter.builtin.title
  (
    $|<!DOCTYPE html>
    $|<html lang="\{lang}" dir="ltr">
    $|<head>
    $|<meta charset="utf-8">
    $|<meta name="viewport" content="width=device-width, initial-scale=1">
    $|\{if title.is_empty() { "" } else { "<title>\{escape_html(title)}</title>" }}
    $|<style>
    $|\{global_css}
    $|\{screen_css}
    $|\{print_css(paper)}
    $|</style>
    $|\{head_extra}
    $|</head>
    $|<body>
    $|<div class="paper">
    $|\{content}
    $|</div>
    $|</body>
    $|</html>
  )
}

///|
pub const TEXT_FONT_SERIF = "KaTeX_Main, serif"

///|
let global_css : String = [
  css_rule("body", [("font-family", TEXT_FONT_SERIF), ("font-size", "20px")]),
  css_rule("p", [("text-align", "justify")]),
].join("\n")

///|
/// CSS for the on-screen default view: the document stays centered with a
/// reasonable width. Only applies to non-print pages.
let screen_css : String = [
  css_media("screen", [
    css_rule("body", [("display", "flex"), ("justify-content", "center")]),
    css_rule(".paper", [
      ("padding", "1.25cm 1.5cm 0cm 1.5cm"),
      ("max-width", "21cm"),
    ]),
  ]),
  css_media("screen and (max-width: 1000px)", [
    css_rule(".paper", [
      ("min-width", "0"), // Allow flex/grid items to shrink below their content's intrinsic width, preventing overflowing content from expanding the layout horizontally.
      ("padding", "0.1cm"),
    ]),
  ]),
].join("\n")

///|
pub fn render_pre(s : String) -> String {
  render_nodes([el("pre", [], [Text(s)])])
}

///|
/// Renders each block and joins them with blank-line separators.
fn join_blocks(
  blocks : Array[@parsing.Block],
  options : HtmlOptions,
) -> Array[Node] {
  interleave(blocks.map(b => b.render(options)), Text("\n"))
}

///|
/// Dispatches a block to its renderer. Add a match arm and a render
/// function here for each block variant.
fn @parsing.Block::render(
  self : @parsing.Block,
  options : HtmlOptions,
) -> Array[Node] {
  match self {
    Heading(level, blocks) => render_heading(level, blocks, options)
    Paragraph(inlines) => render_paragraph(inlines, options)
    UnorderedList(items) => render_list(items, "ul", options)
    OrderedList(items) => render_list(items, "ol", options)
    FencedCode(_, code) => render_fenced_code(code)
    ThematicBreak => render_thematic_break()
    DisplayMath(latex) => render_display_math(latex, options)
    Table(header, rows) => render_table(header, rows, options)
    FootnoteDef(label, blocks) => render_footnote_def(label, blocks, options)
    Text(s) => render_text(s, options)
    Inline(item) =>
      render_inline(
        item,
        options,
        convert=options.halfwidth_punct,
        prev=None,
        next=None,
      )
    Comment(c) => render_comment(c)
    Element(tag, positional, named) =>
      render_element({ tag, positional, named, }, options)
  }
}

///|
fn render_heading(
  level : Int,
  blocks : Array[@parsing.Block],
  options : HtmlOptions,
) -> Array[Node] {
  [el("h\{level}", [], blocks.map(b => b.render(options)).flatten())]
}

///|
fn render_paragraph(
  inlines : Array[@parsing.Inline],
  options : HtmlOptions,
) -> Array[Node] {
  let content = render_inlines(inlines, options)
  guard !render_nodes(content).trim().is_empty() else { [] }
  [el("p", [], content)]
}

///|
fn render_fenced_code(code : String) -> Array[Node] {
  [el("pre", [], [el("code", [], [Text(code)])])]
}

///|
fn render_thematic_break() -> Array[Node] {
  [el("hr", [], [])]
}

///|
fn render_footnote_def(
  label : String,
  blocks : Array[@parsing.Block],
  options : HtmlOptions,
) -> Array[Node] {
  [
    el(
      "div",
      [attr("id", "fn:\{label}")],
      [Text("\n"), ..join_blocks(blocks, options), Text("\n")],
    ),
  ]
}

///|
fn render_text(s : String, options : HtmlOptions) -> Array[Node] {
  guard options.halfwidth_punct else { [Text(s)] }
  [Text(to_halfwidth_punct(s))]
}

///|
fn render_comment(c : String) -> Array[Node] {
  [Raw("<!--\{c}-->")]
}

///|
fn render_list(
  items : Array[@parsing.MdListItem],
  kind : String,
  options : HtmlOptions,
) -> Array[Node] {
  [
    el(
      kind,
      [],
      [
        Text("\n"),
        ..interleave(items.map(e => render_list_item(e, options)), Text("\n")),
        Text("\n"),
      ],
    ),
  ]
}

///|
fn render_list_item(
  item : @parsing.MdListItem,
  options : HtmlOptions,
) -> Array[Node] {
  let checkbox = item.checked.map_or([], checked => {
    if checked {
      [
        el(
          "input",
          [
            attr_flag("checked"),
            attr_flag("disabled"),
            attr("type", "checkbox"),
          ],
          [],
        ),
      ]
    } else {
      [el("input", [attr_flag("disabled"), attr("type", "checkbox")], [])]
    }
  })
  let body = [
    ..checkbox,
    ..render_inlines(item.content, options),
    Text("\n"),
    ..item.children.map(b => b.render(options)).flatten(),
  ]
  [el("li", [], body)]
}

///|
fn render_table(
  header : @parsing.TableRow,
  rows : Array[@parsing.TableRow],
  options : HtmlOptions,
) -> Array[Node] {
  [
    el("table", [], [
      Text("\n"),
      el("thead", [], render_table_row(header, "th", options)),
      Text("\n"),
      el(
        "tbody",
        [],
        [
          Text("\n"),
          ..interleave(
            rows.map(r => render_table_row(r, "td", options)),
            Text("\n"),
          ),
          Text("\n"),
        ],
      ),
      Text("\n"),
    ]),
  ]
}

///|
fn render_table_row(
  row : @parsing.TableRow,
  cell_tag : String,
  options : HtmlOptions,
) -> Array[Node] {
  [
    el(
      "tr",
      [],
      row.cells.map(c => render_table_cell(c, cell_tag, options)).flatten(),
    ),
  ]
}

///|
fn render_table_cell(
  cells : Array[@parsing.Inline],
  cell_tag : String,
  options : HtmlOptions,
) -> Array[Node] {
  [el(cell_tag, [], render_inlines(cells, options))]
}

///|
fn render_inlines(
  inlines : Array[@parsing.Inline],
  options : HtmlOptions,
  prev? : Char? = None,
  next? : Char? = None,
) -> Array[Node] {
  let out = Array()
  for i in 0..<inlines.length() {
    let (prev_c, next_c) = inline_neighbors(inlines, i, prev~, next~)
    out.push(
      render_inline(
        inlines[i],
        options,
        convert=options.halfwidth_punct,
        prev=prev_c,
        next=next_c,
      ),
    )
  }
  out.flatten()
}

///|
fn render_inline(
  inline : @parsing.Inline,
  options : HtmlOptions,
  convert~ : Bool,
  prev~ : Char?,
  next~ : Char?,
) -> Array[Node] {
  match inline {
    Plain(s) => {
      guard convert else { [Text(s)] }
      [Text(to_halfwidth_punct(s, prev~, next~))]
    }
    Strong(inlines) =>
      [el("strong", [], render_inlines(inlines, options, prev~, next~))]
    Emph(inlines) =>
      [el("em", [], render_inlines(inlines, options, prev~, next~))]
    Code(s) => [el("code", [], [Text(s)])]
    Element(tag, positional, named) =>
      render_element({ tag, positional, named, }, options)
    SoftBreak => [Text("\n")]
    HardBreak => [el("br", [], [])]
    InlineMath(latex) => render_inline_math(latex, options)
    FootnoteRef(label) =>
      [el("sup", [], [el("a", [attr("href", "#fn:\{label}")], [Text(label)])])]
  }
}
