///|
test "display math macro definitions render no terminal content" {
  let macro_definition =
    #|\def\thm{\@ifnextchar[{\thm@with}{\thm@without}}
    #|\def\thm@with[#1]{\textbf{Theorem~(#1).}}
    #|\def\thm@without{\textbf{Theorem.}}
  let blocks = [@parsing.DisplayMath(macro_definition)]
  @test.assert_eq(@backend.render_terminal_document(blocks), "")
}

///|
test "empty blocks do not add terminal document separators" {
  let blocks = [
    @parsing.DisplayMath <| (
      #|\def\empty{}
    ),
    @parsing.Paragraph([@parsing.Plain("content")]),
  ]
  @test.assert_eq(@backend.render_terminal_document(blocks), "content")
}

///|
test "display math macro definitions render empty HTML content" {
  let blocks = [
    @parsing.DisplayMath <| (
      #|\def\empty{}
    ),
  ]
  @test.assert_eq(@backend.render_document(blocks, target=Mathml), "")
}

///|
test "inline macro definition paragraphs render no empty HTML paragraphs" {
  let source =
    #|$\gdef\d{\operatorname{d}}$
    #|$\gdef\spaces#1{~ #1 ~}$
    #|$\gdef\eqs{\spaces=}$
  let html = @notiz.compile(source, target=@notiz.Html) catch {
    _ => @test.fail("expected compile to succeed")
  }
  @test.assert_eq(html.contains("<p"), false)
}

///|
test "table unicode line style" {
  let blocks = [
    @parsing.Table(
      { cells: [[@parsing.Plain("H1")], [@parsing.Plain("H2")]], },
      [{ cells: [[@parsing.Plain("C1")], [@parsing.Plain("C2")]], }],
      [Left, Left],
    ),
  ]

  let output =
    #|H1 │ H2
    #|──┼──
    #|C1 │ C2
  @test.assert_eq(
    @backend.render_terminal_document(
      blocks,
      line_style=@backend.LineStyle::Unicode,
      ansi=false,
    ),
    output,
  )
}

///|
test "table ascii line style" {
  let blocks = [
    @parsing.Table(
      { cells: [[@parsing.Plain("H1")], [@parsing.Plain("H2")]], },
      [{ cells: [[@parsing.Plain("C1")], [@parsing.Plain("C2")]], }],
      [Left, Left],
    ),
  ]

  let output =
    #|H1 | H2
    #|--+--
    #|C1 | C2
  @test.assert_eq(
    @backend.render_terminal_document(
      blocks,
      line_style=@backend.LineStyle::Ascii,
      ansi=false,
    ),
    output,
  )
}

///|
test "table with empty header renders" {
  let blocks = [
    @parsing.Table(
      { cells: [[], [], []], },
      [
        {
          cells: [
            [@parsing.Plain("a")],
            [@parsing.Plain("b")],
            [@parsing.Plain("c")],
          ],
        },
      ],
      [Left, Left, Left],
    ),
  ]
  @test.assert_eq(
    @backend.render_terminal_document(blocks, ansi=false),
    "  │   │  \n─┼─┼─\na │ b │ c",
  )
}

///|
test "terminal document default renders ansi" {
  let blocks = [@parsing.Heading(1, [@parsing.Text("Title")], Map([]))]
  @test.assert_eq(
    @backend.render_terminal_document(blocks).contains("\u{1b}"),
    true,
  )
}

///|
test "terminal document plain text has no ansi" {
  let blocks = [@parsing.Heading(1, [@parsing.Text("Title")], Map([]))]
  @test.assert_eq(
    @backend.render_terminal_document(blocks, ansi=false),
    "Title",
  )
}

///|
test "disable_math keeps inline math literal in terminal" {
  let blocks = [@parsing.Paragraph([@parsing.InlineMath("x^2 = 2")])]
  @test.assert_eq(
    @backend.render_terminal_document(blocks, ansi=false, disable_math=true),
    "$x^2 = 2$",
  )
}

///|
test "disable_math keeps display math literal in terminal" {
  let blocks = [@parsing.DisplayMath("\\sum_{i=1}^n i")]
  @test.assert_eq(
    @backend.render_terminal_document(blocks, ansi=false, disable_math=true),
    "$$\\sum_{i=1}^n i$$",
  )
}
