///|
/// AST types
pub(all) enum Inline {
  Plain(String)
  Strong(Array[Inline])
  Emph(Array[Inline])
  Code(String)
  Content(Array[Block])
  SoftBreak
  HardBreak
  InlineMath(String)
  FootnoteRef(String)
} derive(Eq, Debug)

///|
pub extend Inline with Eq::{not_equal, equal}

///|
pub extend Inline with Debug::{to_repr}

///|
pub(all) enum Block {
  Heading(Int, Array[Block], Map[String, Value])
  Paragraph(Array[Inline])
  UnorderedList(Array[MdListItem])
  OrderedList(Array[MdListItem])
  FencedCode(String?, String)
  DisplayMath(String)
  ThematicBreak
  Table(TableRow, Array[TableRow])
  FootnoteDef(String, Array[Block])
  Text(String)
  Inline(Inline)
  Comment(String)
  Element(String, Array[Value], Map[String, Value])
} derive(Eq, Debug)

///|
pub extend Block with Eq::{not_equal, equal}

///|
pub extend Block with Debug::{to_repr}

///|
pub(all) struct TableRow {
  cells : Array[Array[Inline]]
} derive(Eq, Debug)

///|
pub extend TableRow with Eq::{not_equal, equal}

///|
pub extend TableRow with Debug::{to_repr}

///|
pub(all) struct MdListItem {
  checked : Bool?
  content : Array[Inline]
  children : Array[Block]
} derive(Eq, Debug)

///|
pub extend MdListItem with Eq::{not_equal, equal}

///|
pub extend MdListItem with Debug::{to_repr}

///|
/// One element argument value: a script expression compiled to a typed
/// value. `Content` is a `[ ... ]` content block (a call's trailing content
/// block is the same value as a positional `Content` argument), `Call` a
/// nested call expression.
pub(all) enum Value {
  Text(String)
  Integer(Int)
  Content(Array[Block])
  Call(String, Array[Value], Map[String, Value])
  Comment(String)
} derive(Eq, Debug)

///|
pub extend Value with Eq::{not_equal, equal}

///|
pub extend Value with Debug::{to_repr}

///|
/// Inline parsers
pub let special_chars = "*_`[\\$#="

///|
/// A zero-width guard that succeeds iff the next character is NOT `c`.
///
/// Despite the name, nothing is "delimited": `char(c)` must fail for the
/// guard to succeed, and no input is consumed. Two distinct uses:
///
/// - inside `strong`/`emph`, the guard before each content item fails as
///   soon as the item would start with the delimiter, which ends the
///   repetition and lets the closing delimiter match — this is what makes
///   the FIRST `*`/`_` close the span;
/// - in `paragraph_line`, a chain of guards rejects lines that start with a
///   block marker.
///
/// It is a 1-character absence check, not a 2-character
/// "not-followed-by-another-c" check.
pub fn delim(c : Char) -> @talc.StringParser[Unit] {
  @talc.char(c).not_followed_by("'\{c}'")
}

///|
pub type InlineParser = @talc.StringParser[Inline]

///|
pub type BlockParser = @talc.StringParser[Block]

///|
let hard_break : InlineParser = @talc.char('\\')
  .then(@talc.newline)
  .attempt()
  .map(_ => HardBreak)

///|
let soft_break : InlineParser = @talc.newline.map(_ => SoftBreak)

///|
let escaped : InlineParser = @talc.char('\\')
  .then(@talc.one_of(special_chars + "]"))
  .map(c => Plain(c.to_string()))

///|
let code_span : InlineParser = @talc.char('`')
  .then(@talc.many_chars(@talc.none_of("`")))
  .skip(@talc.char('`'))
  .map(c => Code(c))

///|
/// `$...$` inline math, strict mode.
///
/// A bare `$` in prose is a parse error (`\$` for a literal dollar sign):
/// no alternative in the inline choice can consume `$`, so the `.attempt()`
/// here never changes accept/reject — it only affects error merging.
/// Content must be non-empty (`many_chars1`): `$$` inside a paragraph is an
/// error, not an empty math node. `$$` at line start is display math and
/// never reaches this parser.
let inline_math : InlineParser = @talc.char('$')
  .then(@talc.many_chars1(@talc.none_of("$")))
  .skip(@talc.char('$'))
  .attempt()
  .map(c => InlineMath(c))

///|
/// Evaluate a script expression without consuming following markup whitespace.
fn inline_script() -> InlineParser {
  escape().map(blocks => Inline::Content(blocks))
}

///|
fn footnote_ref() -> InlineParser {
  @talc.string("[^")
  .then(@talc.many_chars1(@talc.none_of("]")))
  .skip(@talc.char(']'))
  .map(label => FootnoteRef(label))
}

///|
/// `*content*` strong.
///
/// Content items are parsed by the full recursive `inline()` parser, so
/// `_emph_` nests inside strong (`*bold _and_ italic*` → Strong with an Emph
/// child), but strong itself does NOT nest: the `delim('*')` guard before
/// each item fails once the next character is `*`, so the first `*` after
/// content closes the span (`*a *b* c*` = strong "a ", plain "b", strong
/// " c"). A `*` that cannot close anything is a parse error (strict mode);
/// write `\*` for a literal star.
fn strong() -> InlineParser {
  @talc.char('*')
  .then(delim('*').then(inline()).some())
  .skip(@talc.char('*'))
  .map(c => Strong(c))
}

///|
/// `_content_` emph: same shape as `strong`, with the same first-`_`-closes
/// rule and the same nesting property (strong can appear inside emph).
fn emph() -> InlineParser {
  @talc.char('_')
  .then(delim('_').then(inline()).some())
  .skip(@talc.char('_'))
  .map(c => Emph(c))
}

///|
let plain_char : InlineParser = {
  let non_special = @talc.none_of(special_chars + "\n\r")
  non_special.bind(c => {
    @talc.many_chars(non_special).map(rest => Plain("\{c}\{rest}"))
  })
}

///|
let plain_bracket : InlineParser = @talc.one_of("[]").map(c => {
  Plain(c.to_string())
})

///|
fn inline() -> InlineParser {
  @talc.delay(() => {
    @talc.choice([
      hard_break,
      escaped,
      inline_script(),
      footnote_ref(),
      strong(),
      emph(),
      inline_math,
      code_span,
      soft_break,
      plain_char,
      plain_bracket,
    ])
  })
}

///|
pub fn parse_inlines(text : String) -> Result[Array[Inline], @talc.ParseError] {
  inline().many().parse(@talc.Input::new(text))
}

///|
/// Parses `text` as inline markdown, as a parser that consumes no input.
///
/// Lets the inline parser be composed in a talc chain, e.g.
/// `rest_of_line.bind(text => inlines(text.trim().to_owned()))`.
fn inlines(text : String) -> @talc.StringParser[Array[Inline]] {
  @talc.Parser::new(input => {
    parse_inlines(text).map(inlines => (inlines, input))
  })
}

///|
/// Block parsers
let line_end : @talc.StringParser[Unit] = @talc.newline
  .map(_ => ())
  .or(@talc.eof())

///|
let blank_line : @talc.StringParser[Unit] = {
  let ws_no_nl = @talc.satisfy("non-newline whitespace", c => {
    Char::is_whitespace(c) && c != '\n'
  })
  @talc.many_chars(ws_no_nl).skip(@talc.newline).map(_ => ()).attempt()
}

///|
let thematic_break : BlockParser = @talc.string("---")
  .then(@talc.char('-').many())
  .skip(line_end)
  .map(_ => ThematicBreak)

///|
/// One inline item of block-level content: plain text, markup inlines, and
/// the script escape `#expr` — shared by document headings, content
/// paragraphs, and content headings.
///
/// `terminators` is the character set that ends the inline run: the content
/// block's `]` in script scope, just newlines in markup. Every unescaped `#`
/// starts a script expression; a failed expression is a syntax error.
///
/// The `delay` breaks the construction cycle `inline_block_item → escape →
/// script_expr → content_block → content_block_item → content_item →
/// inline_block_item`; without it, building the parser tree at module load
/// recurses forever.
fn inline_block_item(terminators : String) -> @talc.StringParser[Array[Block]] {
  @talc.delay(() => {
    let non_special = @talc.none_of(special_chars + terminators)
    let plain = non_special.bind(c => {
      @talc.many_chars(non_special).map(rest => [Block::Text("\{c}\{rest}")])
    })
    @talc.choice([
      @talc.char('\\')
      .then(@talc.one_of(special_chars + "]"))
      .map(c => [Block::Text(c.to_string())]),
      footnote_ref().map(desugar_inline),
      strong().map(desugar_inline),
      emph().map(desugar_inline),
      inline_math.map(desugar_inline),
      code_span.map(desugar_inline),
      escape(),
      plain,
      @talc.char('[').map(_ => [Block::Text("[")]),
    ])
  })
}

///|
/// Heading markers have one to six equals signs followed by whitespace.
fn heading_prefix() -> @talc.StringParser[Int] {
  @talc.char('=')
  .some()
  .bind(equals => {
    let level = equals.length()
    guard level <= 6 else { @talc.fail("heading level must be 1 to 6") }
    @talc.space.map(_ => level)
  })
}

///|
let heading : BlockParser = heading_prefix().bind(level => {
  inline_block_item("\r\n")
  .many()
  .map(items => items.flatten())
  .skip(line_end)
  .map(items => make_heading(level, items, Map([])))
})

///|
fn make_heading(
  level : Int,
  items : Array[Block],
  attributes : Map[String, Value],
) -> Block {
  Heading(level.max(1).min(6), items, attributes)
}

///|
let rest_of_line : @talc.SParser = @talc.many_chars1(@talc.not_newline)
  .bind(content => line_end.map(_ => content + "\n"))
  .or(@talc.newline.map(_ => "\n"))

///|
let fenced_code : BlockParser = {
  let not_nl = @talc.not_newline
  @talc.string("```")
  .then(@talc.many_chars1(not_nl).optional())
  .skip(line_end)
  .bind(lang => {
    let terminator = @talc.string("```").skip(line_end)
    rest_of_line
    .many_until(terminator)
    .map(lines => FencedCode(lang, lines.join("")))
  })
}

///|
/// Paragraph
///
/// A paragraph line may not start with any block marker. These guards are
/// the runtime form of disjoint FIRST sets: every line-starting character
/// maps to exactly one block production, leaving `paragraph` as the
/// "anything else" branch. In particular the `$$` guard means a line
/// starting with `$$` is display math or a hard error — it can never fall
/// back to a paragraph. A line starting with a single `$` is NOT rejected
/// here: it is a paragraph whose leading `$` is parsed as inline math by
/// the inline layer.
let paragraph_line : @talc.SParser = blank_line
  .not_followed_by("blank line")
  .then(delim('#'))
  .then(@talc.string("---").not_followed_by("\"---\""))
  .then(@talc.string("```").not_followed_by("\"```\""))
  .then(@talc.string("$$").not_followed_by("\"$$\""))
  .then(delim('='))
  .then(@talc.char('-').then(@talc.space).not_followed_by("'- '"))
  .then(@talc.char('+').then(@talc.space).not_followed_by("'+ '"))
  .then(delim('|'))
  .then(rest_of_line)

///|
let paragraph : BlockParser = paragraph_line
  .some()
  .bind(lines => {
    let joined = lines.join("")
    let text = if joined.has_suffix("\\\n") {
      joined.trim_start().to_owned()
    } else {
      joined.trim().to_owned()
    }
    inlines(text).map(inlines => Paragraph(inlines))
  })

///|
/// Table
let table_cell : @talc.StringParser[Array[Inline]] = @talc.many_chars(
  @talc.none_of("|\n"),
).bind(text => inlines(text.trim().to_owned()))

///|
fn table_row() -> @talc.StringParser[TableRow] {
  @talc.char('|')
  .then(table_cell)
  .bind(first => {
    @talc.char('|')
    .then(line_end.not_followed_by("trailing pipe"))
    .then(table_cell)
    .attempt()
    .many()
    .map(rest => TableRow::{ cells: [first, ..rest], })
  })
  .skip(@talc.char('|').optional())
  .skip(line_end)
}

///|
let table_delimiter_cell : @talc.StringParser[Unit] = @talc.space
  .many()
  .then(@talc.char(':').optional())
  .then(@talc.char('-').some())
  .then(@talc.char(':').optional())
  .skip(@talc.space.many())
  .map(_ => ())

///|
let table_delimiter_row : @talc.StringParser[Unit] = @talc.char('|')
  .then(table_delimiter_cell)
  .then(@talc.char('|').then(table_delimiter_cell).attempt().many())
  .skip(@talc.char('|').optional())
  .skip(line_end)
  .map(_ => ())

///|
/// A table delimiter row, failing with a clear message at the row start
/// when the header row is not followed by `| --- | --- |`-style markers.
let table_delimiter : @talc.StringParser[Unit] = @talc.Parser::new(input => {
  table_delimiter_row
  .run(input)
  .map_err(_ => {
    @talc.ParseError::message(input, "expected table delimiter row").with_commit()
  })
})

///|
pub fn table() -> BlockParser {
  table_row().bind(header => {
    table_delimiter
    .then(table_row().many())
    .map(rows => {
      for row in rows {
        for _ in header.cells.length()..<row.cells.length() {
          header.cells.push([])
        }
      }
      Table(header, rows)
    })
  })
}

///|
/// Lists
fn task_marker() -> @talc.StringParser[Bool] {
  @talc.choice([
    @talc.string("[ ]").map(_ => false),
    @talc.string("[x]").map(_ => true),
  ])
}

///|
fn list_item(marker : Char, indent : Int) -> @talc.StringParser[MdListItem] {
  let istr = String::repeat(" ", indent)
  @talc.string(istr)
  .then(@talc.char(marker))
  .skip(@talc.space)
  .attempt()
  .then(task_marker().attempt().optional())
  .bind(checked => list_item_body(checked, indent))
}

///|
/// Parses the text of a list item and its sub-lists.
///
/// Sub-lists are looked for at exactly `indent + 2` spaces — a fixed
/// 2-space indentation per nesting level, not a variable-length prefix
/// scan. The `.attempt()` in `list_item` is what lets a failed item body
/// fall back to `paragraph`, unrelated to indentation probing.
fn list_item_body(
  checked : Bool?,
  indent : Int,
) -> @talc.StringParser[MdListItem] {
  @talc.line_content
  .bind(text => inlines(text.trim().to_owned()))
  .skip(@talc.newline.optional())
  .bind(content => {
    sub_list(indent + 2).many().map(children => { checked, content, children, })
  })
}

///|
fn unordered_list_at(indent : Int) -> BlockParser {
  list_item('-', indent).some().map(items => UnorderedList(items))
}

///|
fn ordered_list_at(indent : Int) -> BlockParser {
  list_item('+', indent).some().map(items => OrderedList(items))
}

///|
fn sub_list(indent : Int) -> BlockParser {
  @talc.choice([unordered_list_at(indent), ordered_list_at(indent)])
}

///|
let unordered_list : BlockParser = unordered_list_at(0)

///|
let ordered_list : BlockParser = ordered_list_at(0)

///|
/// Footnote definition
let footnote_def : BlockParser = @talc.char('[')
  .then(@talc.char('^'))
  .then(@talc.many_chars1(@talc.none_of("]")))
  .skip(@talc.string("]:"))
  .skip(@talc.space)
  .bind(label => {
    rest_of_line.bind(text => {
      inlines(text.trim().to_owned()).map(inlines => {
        FootnoteDef(label, [Paragraph(inlines)])
      })
    })
  })
  .attempt()

///|
/// Display math block
///
/// The trailing `.attempt()` is load-bearing, not cleanup: `bind`/`then`
/// commit a failure once input has been consumed, so without it a line
/// starting with a single `$` would die with a committed error and never
/// fall through to `paragraph`. The block-level `$` decision is effectively
/// 2-character lookahead: `$$` → display math; single `$` → paragraph
/// (where the leading `$` is inline math). An unclosed `$$` line is a hard
/// error — the `$$` paragraph guard rejects it before `paragraph` is tried.
let display_math_block : BlockParser = @talc.string("$$")
  .bind(_ => {
    @talc.choice([
      @talc.newline.bind(_ => {
        let terminator = @talc.string("$$").skip(@talc.newline.optional())
        rest_of_line
        .many_until(terminator)
        .map(lines => DisplayMath(lines.join("").trim_end().to_owned()))
      }),
      @talc.many_chars(@talc.none_of("$"))
      .skip(@talc.string("$$"))
      .skip(@talc.newline.optional())
      .map(content => DisplayMath(content.trim().to_owned())),
    ])
  })
  .attempt()

///|
/// `#expr` — a script block: the document-level escape from markup into
/// the script scope. No whitespace is allowed between `#` and the expression.
/// The expression's result is spliced into the document flow.
let script_block : @talc.StringParser[Array[Block]] = escape()

///|
/// Document
fn block() -> @talc.StringParser[Array[Block]] {
  @talc.choice([
    script_block,
    @talc.choice([
      thematic_break,
      heading,
      fenced_code,
      display_math_block,
      footnote_def,
      table(),
      unordered_list,
      ordered_list,
      paragraph,
    ]).map(item => [item]),
  ])
}

///|
fn blocks() -> @talc.StringParser[Array[Block]] {
  block()
  .bind(head => {
    blank_line
    .many()
    .then(block())
    .attempt()
    .many()
    .map(tail => [head, ..tail].flatten())
  })
  .or(@talc.pure([]))
}

///|
/// The full document: optional leading blank lines, optional frontmatter,
/// then the blocks. Returns the frontmatter (the default one when the
/// document has no frontmatter block) alongside the blocks.
pub let document_with_metadata : @talc.StringParser[(Frontmatter, Array[Block])] = blank_line
  .many()
  .then(frontmatter.or(@talc.pure(default_frontmatter)))
  .skip(blank_line.many())
  .bind(metadata => blocks().map(blocks => (metadata, blocks)))
  .skip(blank_line.many())
  .skip(@talc.eof())

///|
/// The full document: optional leading blank lines, optional frontmatter,
/// then the blocks. The frontmatter itself is discarded; parse it with
/// [`document_with_metadata`](`document_with_metadata`) if the metadata is
/// needed.
pub let document : @talc.StringParser[Array[Block]] = document_with_metadata.map(pair => {
    pair.1
  },
)
