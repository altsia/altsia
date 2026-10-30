///|
fn parse_content(source : String) -> Array[@parsing.Content] {
  @parsing.document.parse(@talc.Input::new(source)).unwrap()
}

///|
fn content_html(source : String, halfwidth~ : Bool = false) -> String {
  @backend.render_document(
    @document.organize(parse_content(source)),
    target=Unicode,
    halfwidth_punct=halfwidth,
  )
}

///|
fn content_text(source : String, halfwidth~ : Bool = false) -> String {
  @backend.render_terminal_document(
    @document.organize(parse_content(source)),
    ansi=false,
    halfwidth_punct=halfwidth,
  )
}

///|
test "parsing preserves line breaks and paragraph separators without paragraphs" {
  @test.assert_eq(parse_content("\n\na"), [@parsing.ParagraphBreak, Text("a")])
  @test.assert_eq(parse_content("a\nb\n\nc"), [
    @parsing.Text("a"),
    SoftBreak,
    Text("b"),
    SoftBreak,
    ParagraphBreak,
    Text("c"),
  ])
  @test.assert_eq(parse_content("#span[a\n\nb]"), [
    @parsing.Element(
      "span",
      [Content([Text("a"), SoftBreak, ParagraphBreak, Text("b")])],
      Map([]),
    ),
  ])
  let (metadata, content) = @parsing.document_with_metadata
    .parse(@talc.Input::new("\n---\ntitle: T\n---\n\na"))
    .unwrap()
  @test.assert_eq(metadata.builtin.title, "T")
  @test.assert_eq(content, [@parsing.ParagraphBreak, Text("a")])
}

///|
test "parsing preserves structural content inside emphasis and headings" {
  let expected : Array[@parsing.Content] = [
    Text("a "),
    Strong([Element("quote", [Content([Text("b")])], Map([]))]),
    Text(" c"),
  ]
  @test.assert_eq(parse_content("a *#quote[b]* c"), expected)
  @test.assert_eq(@parsing.parse_script("[a *#quote[b]* c]").unwrap(), expected)
  @test.assert_eq(parse_content("= #heading[Inner]"), [
    @parsing.Heading(1, [Heading(1, [Text("Inner")], Map([]))], Map([])),
  ])
}

///|
test "organization assembles paragraphs after splicing content" {
  let content = parse_content("a #[b\n\nc] d")
  @test.assert_eq(@document.organize(content), [
    @document.Paragraph([Text("a "), Text("b")]),
    Paragraph([Text("c"), Text(" d")]),
  ])
  @test.assert_eq(content, parse_content("a #[b\n\nc] d"))
  @test.assert_eq(content_text("#[a*b*c]"), "abc")
  @test.assert_eq(content_html("#[a*b*c]"), "<p>a<strong>b</strong>c</p>")
  @test.assert_eq(content_html("#span[hello]"), "<p><span>hello</span></p>")
  @test.assert_eq(@notiz.compile("#[a*b*c]", target=Text), "abc")
}

///|
test "organization discovers blocks inside nested emphasis" {
  let organized = @document.organize(parse_content("a *#quote[b]* c"))
  @test.assert_eq(organized, [
    @document.Paragraph([Text("a")]),
    Strong([
      Element({
        tag: "quote",
        positional: [],
        named: Map([]),
        content: [InlineRun([Text("b")])],
      }),
    ]),
    Paragraph([Text("c")]),
  ])
  @test.assert_eq(content_text("a *#quote[b]* c"), "a\n\n│ b\n\nc")
  @test.assert_eq(
    content_html("a *#quote[b]* c"),
    "<p>a</p>\n<div style=\"font-weight: bold\"><blockquote>\nb\n</blockquote></div>\n<p>c</p>",
  )
  @test.assert_eq(
    content_text("a *_x #quote[b] y_* c"),
    "a\n\nx\n\n│ b\n\ny\n\nc",
  )
}

///|
test "paragraph boundaries survive content arguments and nested calls" {
  @test.assert_eq(
    content_html("#quote[a\n\nb]"),
    "<blockquote>\n<p>a</p><p>b</p>\n</blockquote>",
  )
  @test.assert_eq(content_text("#quote[a\n\nb]"), "│ a\n│ \n│ b")
  @test.assert_eq(
    content_text("#quote(attribution: span[a\n\nb])[q]"),
    "│ q\n│         --- a\n│ \n│ b",
  )
  @test.assert_eq(content_text("#span([a], [b])"), "ab")
  @test.assert_eq(content_text("#quote([a], [b\n\nc])"), "│ ab\n│ \n│ c")
  @test.assert_eq(
    content_html("#quote([a], [b\n\nc])"),
    "<blockquote>\n<p>ab</p><p>c</p>\n</blockquote>",
  )
  @test.assert_eq(content_text("#quote([a\n\n], [b])"), "│ a\n│ \n│ b")
  @test.assert_eq(content_text("#span(span[ignored])[shown]"), "shown")
}

///|
test "flow preparation covers list items and table cells" {
  @test.assert_eq(content_text("- a *#quote[b]* c"), "• a\n\n│ b\n\nc")
  @test.assert_eq(
    content_html("| *#quote[b]* |\n| --- |"),
    "<table>\n<thead><tr><th style=\"text-align: left\"><div style=\"font-weight: bold\"><blockquote>\nb\n</blockquote></div></th></tr></thead>\n<tbody>\n\n</tbody>\n</table>",
  )
  @test.assert_eq(
    content_text("- first\n  - child\n- second"),
    "• first\n  • child\n• second",
  )
}

///|
test "inline runs retain whitespace and punctuation across content boundaries" {
  @test.assert_eq(content_html("* a *"), "<p><strong> a </strong></p>")
  @test.assert_eq(content_html("=  title  "), "<h1> title  </h1>")
  @test.assert_eq(
    content_html("a *_b_* c"),
    "<p>a <strong><em>b</em></strong> c</p>",
  )
  @test.assert_eq(content_html("#[a\\\nb]"), "<p>a<br>b</p>")
  @test.assert_eq(
    content_html("= 你，*好*", halfwidth=true),
    "<h1>你, <strong>好</strong></h1>",
  )
  for
    (source, html) in [
      ("#span[你，*好*]", "<p><span>你, <strong>好</strong></span></p>"),
      ("你，#span[好]", "<p>你, <span>好</span></p>"),
      ("#span[你，]好", "<p><span>你, </span>好</p>"),
    ] {
    @test.assert_eq(content_text(source, halfwidth=true), "你, 好")
    @test.assert_eq(content_html(source, halfwidth=true), html)
  }
  @test.assert_eq(content_text("  ` x ` $x$  ", halfwidth=true), " x  x")
}

///|
test "strict syntax and block prefixes are preserved by content parsing" {
  for
    source in [
      "a = b", "a | b", "#?", "#span(1,)", "*open", "$$open", "\n---\ninvalid\n---",
    ] {
    @test.assert_eq(
      @parsing.document.parse(@talc.Input::new(source)) is Err(_),
      true,
    )
  }
  @test.assert_eq(content_text("a \\= b \\| c"), "a = b | c")
  @test.assert_eq(content_html("a\n= title"), "<p>a</p>\n<h1>title</h1>")
  @test.assert_eq(
    content_html("a\n\n[^b]: note"),
    "<p>a</p>\n<div id=\"fn:b\">\n<p>note</p>\n</div>",
  )
  @test.assert_eq(content_text("a\n[^b]: note"), "a\n[b]: note")
}
