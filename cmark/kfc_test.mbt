///|
test "KFC emphasis ignores whitespace punctuation and word boundaries" {
  @test.assert_eq(
    @cmark.parse("a_ b _c", @cmark.Options::empty())
    is [
      Start(Paragraph),
      Text("a"),
      Start(Emphasis),
      Text(" b "),
      End(Emphasis),
      Text("c"),
      End(Paragraph),
    ],
    true,
  )
  @test.assert_eq(
    @cmark.parse("a** ! **b", @cmark.Options::empty())
    is [
      Start(Paragraph),
      Text("a"),
      Start(Strong),
      Text(" ! "),
      End(Strong),
      Text("b"),
      End(Paragraph),
    ],
    true,
  )
}

///|
test "KFC rejects invalid emphasis rather than falling back to text" {
  for
    source in [
      "a***b***", "___", "*a_", "**a*", "*unclosed", "a_", "*a **b** c*",
    ] {
    @test.assert_raise(() => @cmark.parse(source, @cmark.Options::empty()))
  }
  let error = @test.expect_error(() => {
    @cmark.parse("*open\n\nclosed*", @cmark.Options::empty())
  })
  @test.assert_eq(error is @cmark.SyntaxError::UnclosedEmphasis(_, _), true)
}

///|
test "KFC emphasis cannot nest through link or image text" {
  for source in ["*[**nested**](url)*", "**![alt *nested*](img)**"] {
    let error = @test.expect_error(() => {
      @cmark.parse(source, @cmark.Options::empty())
    })
    @test.assert_eq(error is @cmark.SyntaxError::NestedEmphasis(_, _), true)
  }
}

///|
test "KFC literal contexts do not parse emphasis" {
  let options = @cmark.enable_math()
  @test.assert_eq(
    @cmark.parse("`***` $ _ $ \\*", options)
    is [
      Start(Paragraph),
      Code("***"),
      Text(" "),
      InlineMath(" _ "),
      Text(" "),
      Text("*"),
      End(Paragraph),
    ],
    true,
  )
  @test.assert_eq(
    @cmark.parse("[text](path_with_underscores)", options)
    is [
      Start(Paragraph),
      Start(Link(dest_url="path_with_underscores", ..)),
      Text("text"),
      End(Link),
      End(Paragraph),
    ],
    true,
  )
}

///|
test "KFC math has no surrounding whitespace or digit restrictions" {
  @test.assert_eq(
    @cmark.parse("a$ x $2", @cmark.enable_math())
    is [
      Start(Paragraph),
      Text("a"),
      InlineMath(" x "),
      Text("2"),
      End(Paragraph),
    ],
    true,
  )
  @test.assert_eq(
    @cmark.parse("a$$ x $$2", @cmark.enable_math())
    is [
      Start(Paragraph),
      Text("a"),
      DisplayMath(" x "),
      Text("2"),
      End(Paragraph),
    ],
    true,
  )
}

///|
test "KFC headings are ATX only including inside containers" {
  @test.assert_eq(
    @cmark.parse("# Heading", @cmark.Options::empty())
    is [Start(Heading(level=H1, ..)), Text("Heading"), End(Heading(H1))],
    true,
  )
  @test.assert_eq(
    @cmark.parse("> Heading\n> ===", @cmark.Options::empty())
    is [
      Start(BlockQuote(None)),
      Start(Paragraph),
      Text("Heading"),
      SoftBreak,
      Text("==="),
      End(Paragraph),
      End(BlockQuote(None)),
    ],
    true,
  )
  @test.assert_eq(
    @cmark.parse("Heading\n---", @cmark.Options::empty())
    is [Start(Paragraph), Text("Heading"), End(Paragraph), Rule],
    true,
  )
}

///|
test "KFC code blocks require backtick fences" {
  @test.assert_eq(
    @cmark.parse("```\n***\n```", @cmark.Options::empty())
    is [Start(CodeBlock(Fenced(""))), Text("***\n"), End(CodeBlock)],
    true,
  )
  @test.assert_eq(
    @cmark.parse("~~~\ntext\n~~~", @cmark.Options::empty())
    is [
      Start(Paragraph),
      Text("~~~"),
      SoftBreak,
      Text("text"),
      SoftBreak,
      Text("~~~"),
      End(Paragraph),
    ],
    true,
  )
  @test.assert_eq(
    @cmark.parse("    **text**", @cmark.Options::empty())
    is [
      Start(Paragraph),
      Start(Strong),
      Text("text"),
      End(Strong),
      End(Paragraph),
    ],
    true,
  )
}

///|
test "KFC emphasis composes with optional inline extensions" {
  let options = @cmark.enable_strikethrough()
  @test.assert_eq(
    @cmark.parse("~~*text*~~", options)
    is [
      Start(Paragraph),
      Start(Strikethrough),
      Start(Emphasis),
      Text("text"),
      End(Emphasis),
      End(Strikethrough),
      End(Paragraph),
    ],
    true,
  )
  @test.assert_raise(() => @cmark.parse("*a ~~b* c~~*", options))
}

///|
test "KFC tilde delimiters ignore boundaries and retain nested meanings" {
  let options = @cmark.enable_subscript()
  options.insert(@cmark.enable_strikethrough())
  @test.assert_eq(
    @cmark.parse("文~~ ~ + ~ ~~字", options)
    is [
      Start(Paragraph),
      Text("文"),
      Start(Strikethrough),
      Text(" "),
      Start(Subscript),
      Text(" + "),
      End(Subscript),
      Text(" "),
      End(Strikethrough),
      Text("字"),
      End(Paragraph),
    ],
    true,
  )
}
