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
test "KFC leaves named and numeric character references in prose" {
  let source = "&copy; &#169; &#xA9;"
  @test.assert_eq(
    @cmark.parse(source, @cmark.Options::empty())
    is [Start(Paragraph), Text("&copy; &#169; &#xA9;"), End(Paragraph)],
    true,
  )
}

///|
test "KFC leaves character references in inline and reference link fields" {
  for
    source in [
      "[x](/?a=1&amp;b=2 \"&copy; &#169;\")", "[x][ref]\n\n[ref]: /?a=1&amp;b=2 \"&copy; &#169;\"",
    ] {
    @test.assert_eq(
      @cmark.parse(source, @cmark.Options::empty())
      is [
        Start(Paragraph),
        Start(Link(dest_url="/?a=1&amp;b=2", title="&copy; &#169;", ..)),
        Text("x"),
        End(Link),
        End(Paragraph),
      ],
      true,
    )
  }
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
    @cmark.parse("```mbt extra\n***\n```", @cmark.Options::empty())
    is [Start(CodeBlock("mbt extra")), Text("***\n"), End(CodeBlock)],
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
test "KFC scripts are TeX inside math; underscores still delimit emphasis" {
  let source = "H^+^。 H~2~O _word_ $x_i^2$ $$\\mathrm{NH}_4^{+}$$"
  @test.assert_eq(
    @cmark.parse(source, @cmark.enable_math())
    is [
      Start(Paragraph),
      Text("H^+^。 H~2~O "),
      Start(Emphasis),
      Text("word"),
      End(Emphasis),
      Text(" "),
      InlineMath("x_i^2"),
      Text(" "),
      DisplayMath("\\mathrm{NH}_4^{+}"),
      End(Paragraph),
    ],
    true,
  )
}

///|
test "KFC treats double equals as ordinary text" {
  let source = "==注意！==。 ==注意！==事項"
  @test.assert_eq(
    @cmark.parse(source, @cmark.Options::empty())
    is [
      Start(Paragraph),
      Text("==注意！==。 ==注意！==事項"),
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
test "KFC single and double tildes retain strikethrough pairing" {
  let options = @cmark.enable_strikethrough()
  @test.assert_eq(
    @cmark.parse("文~~ ~ + ~ ~~字", options)
    is [
      Start(Paragraph),
      Text("文"),
      Start(Strikethrough),
      Text(" "),
      Start(Strikethrough),
      Text(" + "),
      End(Strikethrough),
      Text(" "),
      End(Strikethrough),
      Text("字"),
      End(Paragraph),
    ],
    true,
  )
}
