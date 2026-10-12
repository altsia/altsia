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
  Table(TableRow, Array[TableRow], Array[TableAlignment])
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
/// Structural nodes interrupt paragraphs; inline values compose within them.
pub fn Block::is_inline(self : Block) -> Bool {
  match self {
    Text(_) | Inline(_) | Comment(_) => true
    Element(tag, _, _) => tag != "quote" && tag != "pagebreak"
    _ => false
  }
}

///|
pub(all) enum TableAlignment {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub extend TableAlignment with Eq::{not_equal, equal}

///|
pub extend TableAlignment with Debug::{to_repr}

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
pub let special_chars = "*_`[\\$#=|"

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
/// - in `paragraph_start`, a chain of guards rejects lines that start with a
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
fn strong(terminators : String, paragraph~ : Bool) -> InlineParser {
  @talc.char('*')
  .then(delim('*').then(inline(terminators~, paragraph~)).some())
  .skip(@talc.char('*'))
  .map(c => Strong(c))
}

///|
/// `_content_` emph: same shape as `strong`, with the same first-`_`-closes
/// rule and the same nesting property (strong can appear inside emph).
fn emph(terminators : String, paragraph~ : Bool) -> InlineParser {
  @talc.char('_')
  .then(delim('_').then(inline(terminators~, paragraph~)).some())
  .skip(@talc.char('_'))
  .map(c => Emph(c))
}

///|
fn plain_char(terminators : String) -> InlineParser {
  let non_special = @talc.none_of(special_chars + "\n\r" + terminators)
  non_special.bind(c => {
    @talc.many_chars(non_special).map(rest => Plain("\{c}\{rest}"))
  })
}

///|
fn inline(
  terminators? : String = "",
  paragraph? : Bool = false,
) -> InlineParser {
  @talc.delay(() => {
    let breaks = if terminators.contains("\n") {
      []
    } else {
      [hard_break, soft_break]
    }
    let brackets = if terminators.contains("]") { "[" } else { "[]" }
    let item = @talc.choice(
      [
        ..breaks,
        escaped,
        inline_script(),
        footnote_ref(),
        strong(terminators, paragraph~),
        emph(terminators, paragraph~),
        inline_math,
        code_span,
        plain_char(terminators),
        @talc.one_of(brackets).map(c => Plain(c.to_string())),
      ],
    )
    @talc.Parser::new(input => {
      if paragraph && input.position().column == 1 {
        paragraph_start.then(item).run(input)
      } else {
        item.run(input)
      }
    })
  })
}

///|
pub fn parse_inlines(text : String) -> Result[Array[Inline], @talc.ParseError] {
  inline().many().parse(@talc.Input::new(text))
}

///|
/// Trim paragraph/cell edges without changing code, math, or hard breaks.
fn trim_inlines(items : Array[Inline]) -> Array[Inline] {
  let start = for i = 0; i < items.length(); {
    match items[i] {
      SoftBreak => continue i + 1
      Plain(text) if text.trim().is_empty() => continue i + 1
      _ => break i
    }
  } nobreak {
    items.length()
  }
  let end = for i = items.length(); i > start; {
    match items[i - 1] {
      SoftBreak => continue i - 1
      Plain(text) if text.trim().is_empty() => continue i - 1
      _ => break i
    }
  } nobreak {
    start
  }
  let trimmed = items[start:end].to_owned()
  if trimmed.get(0) is Some(Plain(text)) {
    trimmed[0] = Plain(text.trim_start().to_owned())
  }
  if trimmed.last() is Some(Plain(text)) {
    trimmed[trimmed.length() - 1] = Plain(text.trim_end().to_owned())
  }
  trimmed
}

///|
/// Block parsers
let line_end : @talc.StringParser[Unit] = @talc.newline
  .map(_ => ())
  .or(@talc.eof())

///|
/// The enclosing content delimiter ends a markup line without being consumed.
fn markup_line_end(closing : String) -> @talc.StringParser[Unit] {
  guard !closing.is_empty() else { return line_end }
  line_end.or(
    @talc.Parser::new(input => {
      if input.remaining().has_prefix(closing.to_string_view()) {
        Ok(((), input))
      } else {
        Err(@talc.ParseError::new(input, "end of markup line"))
      }
    }),
  )
}

///|
let blank_line : @talc.StringParser[Unit] = {
  let ws_no_nl = @talc.satisfy("non-newline whitespace", c => {
    Char::is_whitespace(c) && c != '\n'
  })
  @talc.many_chars(ws_no_nl).skip(@talc.newline).map(_ => ()).attempt()
}

///|
fn thematic_break(closing : String) -> BlockParser {
  @talc.string("---")
  .then(@talc.char('-').many())
  .skip(markup_line_end(closing))
  .map(_ => ThematicBreak)
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
fn heading(closing : String) -> BlockParser {
  heading_prefix().bind(level => {
    inline(terminators="\r\n" + closing)
    .many()
    .map(items => items.map(desugar_inline).flatten())
    .skip(markup_line_end(closing))
    .map(items => make_heading(level, items, Map([])))
  })
}

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
fn fenced_code(closing : String) -> BlockParser {
  let not_nl = @talc.not_newline
  @talc.string("```")
  .then(@talc.many_chars1(not_nl).optional())
  .skip(line_end)
  .bind(lang => {
    let terminator = @talc.string("```").skip(markup_line_end(closing))
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
let paragraph_start : @talc.StringParser[Unit] = blank_line
  .not_followed_by("blank line")
  .then(@talc.string("---").not_followed_by("\"---\""))
  .then(@talc.string("```").not_followed_by("\"```\""))
  .then(@talc.string("$$").not_followed_by("\"$$\""))
  .then(delim('='))
  .then(@talc.char('-').then(@talc.space).not_followed_by("'- '"))
  .then(@talc.char('+').then(@talc.space).not_followed_by("'+ '"))
  .then(delim('|'))

///|
fn paragraph(closing : String) -> @talc.StringParser[Array[Block]] {
  paragraph_start
  .then(inline(terminators=closing, paragraph=true).some())
  .map(items => paragraph_flow(trim_inlines(items)))
}

///|
/// Script values join the surrounding inline flow. Block values interrupt it
/// just as their markup syntax does, without nesting blocks inside paragraphs.
fn paragraph_flow(items : Array[Inline]) -> Array[Block] {
  if items is [Content(blocks)] {
    return blocks
  }
  let flow = Array()
  let pending = Array()
  for item in items {
    guard item is Content(blocks) else {
      pending.push(item)
      continue
    }
    for block in blocks {
      guard block.is_inline() else {
        append_paragraph(flow, pending)
        flow.push(block)
        continue
      }
      match block {
        Text(text) => pending.push(Plain(text))
        Inline(inline) => pending.push(inline)
        _ => pending.push(Content([block]))
      }
    }
  }
  append_paragraph(flow, pending)
  flow
}

///|
fn append_paragraph(flow : Array[Block], pending : Array[Inline]) -> Unit {
  let content = trim_inlines(pending)
  if !content.is_empty() {
    flow.push(Paragraph(content))
  }
  pending.clear()
}

///|
/// Table
fn table_cell(closing : String) -> @talc.StringParser[Array[Inline]] {
  inline(terminators="|\r\n" + closing).many().map(trim_inlines)
}

///|
fn table_row(closing : String) -> @talc.StringParser[TableRow] {
  @talc.char('|')
  .then(table_cell(closing))
  .bind(first => {
    @talc.char('|')
    .then(markup_line_end(closing).not_followed_by("trailing pipe"))
    .then(table_cell(closing))
    .attempt()
    .many()
    .map(rest => TableRow::{ cells: [first, ..rest], })
  })
  .skip(@talc.char('|').optional())
  .skip(markup_line_end(closing))
}

///|
let table_delimiter_cell : @talc.StringParser[TableAlignment] = @talc.space
  .many()
  .then(@talc.char(':').optional())
  .bind(left => {
    @talc.char('-')
    .some()
    .then(@talc.char(':').optional())
    .map(right => {
      if right is None {
        Left
      } else if left is Some(_) {
        Center
      } else {
        Right
      }
    })
  })
  .skip(@talc.space.many())

///|
fn table_delimiter_row(
  closing : String,
) -> @talc.StringParser[Array[TableAlignment]] {
  @talc.char('|')
  .then(table_delimiter_cell)
  .bind(first => {
    @talc.char('|')
    .then(table_delimiter_cell)
    .attempt()
    .many()
    .map(rest => [first, ..rest])
  })
  .skip(@talc.char('|').optional())
  .skip(markup_line_end(closing))
}

///|
/// A table delimiter row, failing with a clear message at the row start
/// when the header row is not followed by `| --- | --- |`-style markers.
fn table_delimiter(
  closing : String,
) -> @talc.StringParser[Array[TableAlignment]] {
  @talc.Parser::new(input => {
    table_delimiter_row(closing)
    .run(input)
    .map_err(_ => {
      @talc.ParseError::message(input, "expected table delimiter row").with_commit()
    })
  })
}

///|
pub fn table(closing? : String = "") -> BlockParser {
  table_row(closing).bind(header => {
    table_delimiter(closing).bind(alignments => {
      table_row(closing)
      .many()
      .map(rows => {
        for _ in header.cells.length()..<alignments.length() {
          header.cells.push([])
        }
        for row in rows {
          for _ in header.cells.length()..<row.cells.length() {
            header.cells.push([])
          }
        }
        for _ in alignments.length()..<header.cells.length() {
          alignments.push(Left)
        }
        Table(header, rows, alignments)
      })
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
fn list_item(
  marker : Char,
  indent : Int,
  closing : String,
) -> @talc.StringParser[MdListItem] {
  let istr = String::repeat(" ", indent)
  @talc.string(istr)
  .then(@talc.char(marker))
  .skip(@talc.space)
  .attempt()
  .then(task_marker().attempt().optional())
  .bind(checked => list_item_body(checked, indent, closing))
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
  closing : String,
) -> @talc.StringParser[MdListItem] {
  inline(terminators="\r\n" + closing)
  .many()
  .map(trim_inlines)
  .skip(markup_line_end(closing))
  .bind(content => {
    sub_list(indent + 2, closing)
    .many()
    .map(children => { checked, content, children, })
  })
}

///|
fn unordered_list_at(indent : Int, closing : String) -> BlockParser {
  list_item('-', indent, closing).some().map(items => UnorderedList(items))
}

///|
fn ordered_list_at(indent : Int, closing : String) -> BlockParser {
  list_item('+', indent, closing).some().map(items => OrderedList(items))
}

///|
fn sub_list(indent : Int, closing : String) -> BlockParser {
  @talc.choice([
    unordered_list_at(indent, closing),
    ordered_list_at(indent, closing),
  ])
}

///|
/// Footnote definition
fn footnote_def(closing : String) -> BlockParser {
  @talc.char('[')
  .then(@talc.char('^'))
  .then(@talc.many_chars1(@talc.none_of("]")))
  .skip(@talc.string("]:"))
  .skip(@talc.space)
  .bind(label => {
    inline(terminators="\r\n" + closing)
    .many()
    .map(trim_inlines)
    .skip(markup_line_end(closing))
    .map(inlines => FootnoteDef(label, [Paragraph(inlines)]))
  })
  .attempt()
}

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
/// Shared markup grammar. The opening `[` acts as a virtual line start;
/// subsequent block markers must occur at a physical line start.
fn block(closing : String, start : Int) -> @talc.StringParser[Array[Block]] {
  @talc.Parser::new(input => {
    guard input.cursor() == start || input.position().column == 1 else {
      return paragraph(closing).run(input)
    }
    @talc.choice([
      @talc.choice([
        thematic_break(closing),
        heading(closing),
        fenced_code(closing),
        display_math_block,
        footnote_def(closing),
        table(closing~),
        unordered_list_at(0, closing),
        ordered_list_at(0, closing),
      ]).map(item => [item]),
      paragraph(closing),
    ]).run(input)
  })
}

///|
fn blocks(closing? : String = "") -> @talc.StringParser[Array[Block]] {
  blank_line
  .many()
  .then(
    @talc.Parser::new(input => {
      block(closing, input.cursor()).skip(blank_line.many()).many().run(input)
    }),
  )
  .map(items => items.flatten())
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
