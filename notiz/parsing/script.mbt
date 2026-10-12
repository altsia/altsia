///|
/// The script scope: a Typst-style call syntax layered on top of the markup
/// scope. A script source is a sequence of expressions — calls, strings,
/// content blocks, comments — compiled to the single block tree. Whitespace
/// is skipped between tokens. Comments are values, including in argument
/// lists, and produce [`Comment`](`Comment`) nodes in document flow.
///
/// Grammar:
///
/// ```
/// expr    ::= call | value
/// call    ::= ident ("(" args? ")")? content-block?
/// args    ::= arg ("," arg)*
/// arg     ::= value | ident ":" value
/// value   ::= call | number | string | content | comment
/// number  ::= [0-9]+
/// string  ::= "..."           // data; \" \\ escapes
/// content ::= "[" blocks "]"  // block-level markup; "]" terminates, "#" escapes back
/// comment ::= "//" line | "/* */" block
/// ```
///
/// A call's trailing content block is at most one item and parses exactly
/// like a positional `Content` argument: `elem[bbb] ≡ elem([bbb])`, and
/// `elem(...)` without a trailing block is equally legal. In the document
/// flow a value displays as its text (`#2` renders "2"); in an argument
/// list it stays a typed value. An evaluated expression must immediately
/// follow `#`, with no intervening whitespace.

///|
/// Wraps `parser` as a token, skipping surrounding whitespace.
fn[T] token(parser : @talc.StringParser[T]) -> @talc.StringParser[T] {
  @talc.spaces().then(parser).skip(@talc.spaces())
}

///|
/// `ident ::= [a-zA-Z_][a-zA-Z0-9_-]*` — tag names are ASCII.
fn identifier() -> @talc.StringParser[String] {
  @talc.satisfy("identifier start", c => {
    Char::is_ascii_alphabetic(c) || c == '_'
  }).bind(first => {
    @talc.many_chars(
      @talc.satisfy("identifier char", c => {
        Char::is_ascii_alphabetic(c) ||
        Char::is_ascii_digit(c) ||
        c == '_' ||
        c == '-'
      }),
    ).map(rest => "\{first}\{rest}")
  })
}

///|
/// `"..."` — data, not text. Escapes are `\"` and `\\`; any other `\` is an
/// error, and raw newlines are not allowed.
let string_char : @talc.StringParser[String] = @talc.choice([
  @talc.char('\\').then(
    @talc.choice([
      @talc.char('"').map(_ => "\""),
      @talc.char('\\').map(_ => "\\"),
    ]),
  ),
  @talc.none_of("\"\n").map(c => c.to_string()),
])

///|
fn string_literal() -> @talc.StringParser[String] {
  @talc.char('"')
  .then(string_char.many())
  .skip(@talc.char('"'))
  .map(pieces => pieces.join(""))
}

///|
/// `// line` — comment to end of line.
fn line_comment() -> @talc.StringParser[String] {
  @talc.string("//")
  .then(@talc.line_content)
  .map(text => text.trim().to_owned())
}

///|
/// One character of block-comment body: any character except the start of
/// the `*/` terminator (which fails the lookahead without consuming).
fn comment_body_char() -> @talc.StringParser[String] {
  @talc.Parser::new(input => {
    if input.remaining().has_prefix("*/".to_string_view()) {
      Err(@talc.ParseError::new(input, "\"*/\""))
    } else {
      input
      .peek()
      .map_or(
        (
          Err(@talc.ParseError::new(input, "\"*/\"")) :
          Result[(String, @talc.Input), @talc.ParseError]),
        c => Ok((c.to_string(), input.advance(c))),
      )
    }
  })
}

///|
/// `/* block */` — may span lines; an unterminated block comment is an
/// error.
fn block_comment() -> @talc.StringParser[String] {
  @talc.string("/*")
  .then(comment_body_char().many())
  .skip(@talc.string("*/"))
  .map(pieces => pieces.join(""))
}

///|
fn comment() -> @talc.StringParser[String] {
  @talc.choice([line_comment(), block_comment()])
}

///|
/// `[0-9]+` — an integer literal. Overflow is a parse error, not a
/// silently wrapped value.
fn number_literal() -> @talc.StringParser[Value] {
  @talc.Parser::new(input => {
    @talc.many_chars1(@talc.satisfy("digit", c => c >= '0' && c <= '9'))
    .run(input)
    .bind(pair => {
      let (text, rest) = pair
      let n = @string.parse_int(text) catch {
        _ =>
          return Err(@talc.ParseError::message(input, "integer out of range"))
      }
      Ok((Integer(n), rest))
    })
  })
}

///|
/// `value ::= call | number | string | content | comment` — one typed argument
/// value.
fn expr_value() -> @talc.StringParser[Value] {
  @talc.choice([
    call_parts().map(parts => {
      let (tag, positional, named) = parts
      Value::Call(tag, positional, named)
    }),
    string_literal().map(s => Value::Text(s)),
    content_block().map(blocks => Value::Content(blocks)),
    comment().map(s => Value::Comment(s)),
    number_literal(),
  ])
}

///|
/// `expr ::= call | value`. Each expression yields a spliceable node
/// sequence: a content block is its markup's items, a bare string or
/// integer is one `Text` node in the flow (`#2` displays as "2").
fn script_expr() -> @talc.StringParser[Array[Block]] {
  expr_value().map(flow_of)
}

///|
/// Converts a script value to document nodes before backend rendering.
pub fn flow_of(value : Value) -> Array[Block] {
  match value {
    Text(s) => [Block::Text(s)]
    Integer(n) => [Block::Text(n.to_string())]
    Content(blocks) => blocks
    Call("heading", positional, named) => {
      let level = if named.get("level") is Some(Integer(level)) {
        level
      } else {
        1
      }
      let content = positional
        .filter_map(value => {
          guard value is Content(blocks) else { return None }
          Some(blocks)
        })
        .flatten()
      let attributes = Map(
        named
        .iter()
        .filter_map(pair => {
          guard pair.0 != "level" else { return None }
          Some(pair)
        })
        .to_array(),
      )
      [make_heading(level, content, attributes)]
    }
    Call(tag, positional, named) => [Element(tag, positional, named)]
    Comment(s) => [Block::Comment(s)]
  }
}

///|
/// `call ::= ident ("(" args? ")")? content-block?`. The
/// trailing content block is at most one item and becomes a positional
/// `Content` argument, so `elem[bbb] ≡ elem([bbb])`.
/// Whitespace after a call belongs to the surrounding scope.
fn call_parts() -> @talc.StringParser[
  (String, Array[Value], Map[String, Value]),
] {
  identifier().bind(tag => {
    optional_call_part('(', paren_args()).bind(pair => {
      optional_call_part('[', content_block()).bind(trailing => {
        let (positional, named) = pair.unwrap_or(([], Map([])))
        let positional = trailing.map_or(positional, blocks => {
          [..positional, Content(blocks)]
        })
        for pair in named.iter() {
          let (name, value) = pair
          match (tag, name) {
            ("heading", "level") => {
              guard value is Integer(_) else {
                return @talc.fail("heading level must be an integer")
              }
            }
            ("image", "width") | ("image", "height") => {
              guard value is Text(_) || value is Integer(_) else {
                return @talc.fail("image \{name} must be a string or integer")
              }
            }
            ("quote", _) | ("draft", _) | ("pagebreak", _) => ()
            _ => {
              guard value is Text(_) else {
                return @talc.fail("\{tag} attribute \{name} must be a string")
              }
            }
          }
        }
        if tag == "image" {
          guard positional.length() <= 1 else {
            return @talc.fail("image accepts at most one positional argument")
          }
          let src = if positional.is_empty() {
            named.get("src")
          } else {
            positional.get(0)
          }
          guard src is Some(Text(_)) else {
            return @talc.fail("image requires a string path")
          }
        }
        @talc.pure((tag, positional, named))
      })
    })
  })
}

///|
/// Absence leaves whitespace untouched; an opening delimiter commits errors.
fn[T] optional_call_part(
  opener : Char,
  parser : @talc.StringParser[T],
) -> @talc.StringParser[T?] {
  @talc.Parser::new(input => {
    guard peek_after_ws(input) == Some(opener) else { return Ok((None, input)) }
    @talc.spaces().then(parser).map(value => Some(value)).run(input)
  })
}

///|
/// `paren_args ::= "(" args? ")"` — positional values and named values,
/// collected separately.
fn paren_args() -> @talc.StringParser[(Array[Value], Map[String, Value])] {
  @talc.char('(')
  .then(arg().sep_by(token(@talc.char(','))))
  .skip(@talc.spaces().then(@talc.char(')')))
  .map(collect_args)
}

///|
/// `arg ::= value | ident ":" value`. One lookahead disambiguates: an
/// identifier followed by `:` is a named argument, anything else is a
/// positional value.
fn arg() -> @talc.StringParser[(String?, Value)] {
  token(
    @talc.Parser::new(input => {
      guard identifier().run(input) is Ok((name, rest)) else {
        return positional_arg(input)
      }
      guard peek_after_ws(rest) is Some(':') else {
        return positional_arg(input)
      }
      @talc.spaces()
      .then(@talc.char(':'))
      .skip(@talc.spaces())
      .then(expr_value())
      .run(rest)
      .bind(pair => {
        let (value, rest) = pair
        Ok(((Some(name), value), rest))
      })
    }),
  )
}

///|
/// One positional argument value; the key is `None`.
fn positional_arg(
  input : @talc.Input,
) -> Result[((String?, Value), @talc.Input), @talc.ParseError] {
  expr_value()
  .run(input)
  .map(pair => {
    let (value, rest) = pair
    ((None, value), rest)
  })
}

///|
/// Splits argument pairs into the positional value array and the named
/// map. The map keeps insertion order; a repeated name overwrites its
/// earlier value.
fn collect_args(
  args : Array[(String?, Value)],
) -> (Array[Value], Map[String, Value]) {
  let positional = Array()
  let named : Map[String, Value] = Map([])
  for pair in args {
    let (key, value) = pair
    guard key is Some(name) else {
      positional.push(value)
      continue
    }
    named.set(name, value)
  }
  (positional, named)
}

///|
/// The next non-whitespace character after `input`, without consuming.
fn peek_after_ws(input : @talc.Input) -> Char? {
  let result : Result[(Array[Char], @talc.Input), @talc.ParseError] = @talc.spaces().run(
    input,
  )
  match result {
    Ok((_, rest)) => rest.peek()
    Err(_) => None
  }
}

///|
/// `content ::= "[" blocks "]"` — block-level markup inside, terminated by
/// the first unbalanced `]` (`\]` for a literal bracket). Block constructs
/// that consume their own `]` (such as `[^label]`) are parsed by
/// their own productions before the terminator is reached.
///
/// A content block is a sequence of block items: heading lines (`= Title`),
/// list blocks (`- a` / `+ a`), and inline content (paragraph text, which
/// keeps soft breaks). Heading lines and paragraphs share the same inline
/// machinery ([`inline_block_item`](`inline_block_item`)), so script
/// escapes (`#expr`) work in both; list text uses the same script expressions
/// through the markup inline parser.
///
/// TODO(fix): paragraph text inside a content block is a flat sequence of
/// `Text`/`Inline`/`Element` blocks, NOT a `Paragraph` like in document scope
/// (`note[hello]` → `[Text("hello")]` vs `hello` → `Paragraph(...)`).
/// Consequently `<p>` wrapping and empty-paragraph elision do not apply.
/// Text still supports halfwidth punctuation conversion. The inline AST can
/// embed script results, but content blocks still use a flat block flow.
fn content_block() -> @talc.StringParser[Array[Block]] {
  @talc.char('[')
  .then(
    @talc.Parser::new(input => {
      content_block_item(input.cursor()).many().run(input)
    }),
  )
  .skip(@talc.char(']'))
  .map(pieces => pieces.flatten())
}

///|
/// One item of content: a heading line, a list block, or inline content.
///
/// Tried in this order because a `=`-line must be claimed by `content_heading`
/// before plain text can misparse it, and a `- ` line must not fall
/// through to plain text either.
fn content_block_item(start : Int) -> @talc.StringParser[Array[Block]] {
  @talc.Parser::new(input => {
    if input.cursor() == start || input.position().column == 1 {
      @talc.choice([content_heading(), content_list(), content_item()]).run(
        input,
      )
    } else {
      content_item().run(input)
    }
  })
}

///|
/// `= Title` — a heading line inside a content block, terminated by the
/// first newline or `]`. The heading text is parsed by the same inline
/// machinery as content paragraphs, so the script escape `#tag(...)` works
/// inside headings. The shared prefix enforces levels 1 to 6 and a separator.
fn content_heading() -> @talc.StringParser[Array[Block]] {
  heading_prefix().bind(level => {
    inline_block_item("\r\n]")
    .many()
    .map(items => items.flatten())
    .skip(@talc.newline.optional())
    .map(items => [make_heading(level, items, Map([]))])
  })
}

///|
/// A list block inside a content block: one or more `- ` or `+ ` lines.
/// The `.attempt()` lets a bare `-x` fall through to plain text.
fn content_list() -> @talc.StringParser[Array[Block]] {
  @talc.choice([
    content_list_item('-').some().map(items => [UnorderedList(items)]),
    content_list_item('+').some().map(items => [OrderedList(items)]),
  ])
}

///|
/// One `- text` line; nested lists are not supported yet.
fn content_list_item(marker : Char) -> @talc.StringParser[MdListItem] {
  @talc.char(marker)
  .skip(@talc.space)
  .attempt()
  .bind(_ => {
    @talc.many_chars(@talc.none_of("\r\n]"))
    .skip(@talc.newline.optional())
    .bind(text => {
      inlines(text.trim().to_owned()).map(ins => {
        checked: None,
        content: ins,
        children: [],
      })
    })
  })
}

///|
/// One item of inline markup inside a content block: a paragraph item, or a
/// line break. Heading lines use [`inline_block_item`](`inline_block_item`)
/// directly, which excludes breaks because a heading is one line.
fn content_item() -> @talc.StringParser[Array[Block]] {
  @talc.delay(() => {
    @talc.choice([
      hard_break.map(desugar_inline),
      soft_break.map(desugar_inline),
      inline_block_item("\r\n]"),
    ])
  })
}

///|
/// The shared markup-to-script escape: evaluate immediately after `#`.
fn escape() -> @talc.StringParser[Array[Block]] {
  @talc.char('#').then(script_expr())
}

///|
/// Keep markup semantics when embedding an inline in headings or content.
fn desugar_inline(item : Inline) -> Array[Block] {
  [Block::Inline(item)]
}

///|
/// One expression with surrounding whitespace. The `.attempt()` matters
/// only when nothing but whitespace matched: without it, a run of trailing
/// whitespace would commit the "no expression here" failure and kill the
/// whole document.
fn spaced_expr() -> @talc.StringParser[Array[Block]] {
  @talc.spaces().then(script_expr()).attempt().skip(@talc.spaces())
}

///|
/// A script source: a sequence of expressions with whitespace and comments
/// between them.
pub let script_document : @talc.StringParser[Array[Block]] = @talc.spaces()
  .then(spaced_expr().many())
  .skip(@talc.spaces())
  .skip(@talc.eof())
  .map(groups => groups.flatten())

///|
/// Parses `source` as a script-scope document — the script-default entry
/// point into the block tree.
pub fn parse_script(source : String) -> Result[Array[Block], @talc.ParseError] {
  script_document.parse(@talc.Input::new(source))
}
