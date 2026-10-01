///|
fn cm_test_render(source : String) -> String {
  cm_test_render_with(source, @cmark.Options::empty())
}

///|
fn cm_test_render_with(source : String, options : @cmark.Options) -> String {
  @backend.render_terminal_events(
    @cmark.parse(source, options),
    line_style=@backend.LineStyle::Unicode,
    ansi=false,
  )
}

///|
fn cm_test_render_halfwidth(
  source : String,
  options : @cmark.Options,
) -> String {
  @backend.render_terminal_events(
    @cmark.parse(source, options),
    line_style=@backend.LineStyle::Unicode,
    ansi=false,
    halfwidth_punct=true,
  )
}

///|
test "heading_levels" {
  @test.assert_eq(cm_test_render("# one"), "one")
  @test.assert_eq(cm_test_render("## two"), "two")
  @test.assert_eq(cm_test_render("### three"), "three")
}

///|
test "emphasis_and_strong" {
  @test.assert_eq(cm_test_render("*em*"), "em")
  @test.assert_eq(cm_test_render("**strong**"), "strong")
  @test.assert_eq(cm_test_render("*em* and **strong**"), "em and strong")
}

///|
test "strikethrough_highlight_superscript" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_strikethrough())
  opts.insert(@cmark.enable_highlight())
  opts.insert(@cmark.enable_superscript())
  opts.insert(@cmark.enable_subscript())
  @test.assert_eq(cm_test_render_with("~~del~~", opts), "del")
  @test.assert_eq(cm_test_render_with("==hi==", opts), "==hi==")
  @test.assert_eq(cm_test_render_with("a^b^", opts), "a^{b}")
  @test.assert_eq(cm_test_render_with("~sub~", opts), "_{sub}")
}

///|
test "blockquote" {
  @test.assert_eq(cm_test_render("> quote"), "│ quote")
}

///|
test "unordered_list" {
  @test.assert_eq(cm_test_render("- a\n- b"), "• a\n• b")
}

///|
test "ordered_list_start_number" {
  @test.assert_eq(cm_test_render("1. a\n2. b"), "1. a\n2. b")
  @test.assert_eq(cm_test_render("3. a"), "3. a")
}

///|
test "task_list_markers" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_tasklists())
  @test.assert_eq(
    cm_test_render_with("- [x] done\n- [ ] todo", opts),
    "✔ done\n○ todo",
  )
}

///|
test "nested_list_indent" {
  @test.assert_eq(cm_test_render("- a\n  - b"), "• a\n  • b")
}

///|
test "fenced_code" {
  @test.assert_eq(cm_test_render("```\ncode\n```"), "code")
}

///|
test "table_with_alignment" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_tables())
  @test.assert_eq(
    cm_test_render_with("| a | b |\n|---|---|\n| c | d |", opts),
    "a │ b\n─┼─\nc │ d",
  )
}

///|
test "link_and_image" {
  @test.assert_eq(
    cm_test_render("[text](https://example.com)"),
    "[text](https://example.com)",
  )
  @test.assert_eq(cm_test_render("![alt](img.png)"), "[img: alt](img.png)")
}

///|
test "thematic_break" {
  @test.assert_eq(cm_test_render("---"), "─".repeat(32))
}

///|
test "footnote" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_footnotes())
  let src = "[^b]: note\n\nref [^b]\n"
  @test.assert_eq(cm_test_render_with(src, opts), "[b]: note\n\nref [b]")
}

///|
test "inline_html_passthrough" {
  @test.assert_eq(cm_test_render("<b>x</b>"), "<b>x</b>")
}

///|
test "halfwidth converts punctuation in text" {
  @test.assert_eq(
    cm_test_render_halfwidth("你好，世界！", @cmark.Options::empty()),
    "你好, 世界!",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("a。b", @cmark.Options::empty()),
    "a. b",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("a，b", @cmark.Options::empty()),
    "a, b",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("你好， abc", @cmark.Options::empty()),
    "你好, abc",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("你好（世界）", @cmark.Options::empty()),
    "你好 (世界)",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("（世界）你好", @cmark.Options::empty()),
    "(世界) 你好",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("a（b）c", @cmark.Options::empty()),
    "a (b) c",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("你好（世界）。", @cmark.Options::empty()),
    "你好 (世界).",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("（（x））", @cmark.Options::empty()),
    "((x))",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("他说“你好”", @cmark.Options::empty()),
    "他说 \"你好\"",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("“你好”他说", @cmark.Options::empty()),
    "\"你好\" 他说",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("“你好。”他说", @cmark.Options::empty()),
    "\"你好.\" 他说",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("他说‘好’！", @cmark.Options::empty()),
    "他说 '好'!",
  )
}

///|
test "halfwidth keeps adjacent full-width punctuation tight" {
  let opts = @cmark.Options::empty()
  @test.assert_eq(cm_test_render_halfwidth("a，!b", opts), "a, !b")
  @test.assert_eq(cm_test_render_halfwidth("你好。)", opts), "你好. )")
  @test.assert_eq(cm_test_render_halfwidth("a!（b）", opts), "a! (b)")
  @test.assert_eq(cm_test_render_halfwidth("a！（b）", opts), "a!(b)")
  @test.assert_eq(cm_test_render_halfwidth("你，　好", opts), "你,　好")
}

///|
test "halfwidth spaces across inline node boundaries" {
  let opts = @cmark.Options::empty()
  @test.assert_eq(cm_test_render_halfwidth("**世界**（", opts), "世界 (")
  @test.assert_eq(
    cm_test_render_halfwidth("a，*世界*（b）", opts),
    "a, 世界 (b)",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("（**世界**）", opts),
    "(世界)",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("“*你好*”他说", opts),
    "\"你好\" 他说",
  )
  @test.assert_eq(
    cm_test_render_halfwidth("![你好，世界](x.png)", opts),
    "[img: 你好, 世界](x.png)",
  )
}

///|
test "halfwidth skips code math and html" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_math())
  @test.assert_eq(
    @backend.render_terminal_events(
      @cmark.parse("`a，b` 和 $x，y$", opts),
      line_style=@backend.LineStyle::Unicode,
      ansi=false,
      disable_math=true,
      halfwidth_punct=true,
    ),
    "a，b 和 $x，y$",
  )
  @test.assert_eq(cm_test_render_halfwidth("```\nc，d\n```", opts), "c，d")
  @test.assert_eq(cm_test_render_halfwidth("<b>x，y</b>", opts), "<b>x, y</b>")
  @test.assert_eq(
    cm_test_render_halfwidth("<div>\nx，y\n</div>", opts),
    "<div>\nx，y\n</div>",
  )
}

///|
test "halfwidth converts punctuation in table cells and link text" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_tables())
  @test.assert_eq(
    cm_test_render_halfwidth("| a，b |\n|----|\n| c，d |", opts),
    "a, b\n────\nc, d",
  )
  @test.assert_eq(
    cm_test_render_halfwidth(
      "[你好，世界](https://example.com/x，y)", opts,
    ),
    "[你好, 世界](https://example.com/x，y)",
  )
}

///|
test "halfwidth off keeps full-width punctuation" {
  @test.assert_eq(
    cm_test_render_with("你好，世界！", @cmark.Options::empty()),
    "你好，世界！",
  )
}

///|
test "math_disable_keeps_literal" {
  let opts = @cmark.Options::empty()
  opts.insert(@cmark.enable_math())
  let src = "inline $x^2$\n\n$$\ny^2\n$$"
  let events = @cmark.parse(src, opts)
  @test.assert_eq(
    @backend.render_terminal_events(events, ansi=false, disable_math=true),
    "inline $x^2$\n\n$$\ny^2\n$$",
  )
}
