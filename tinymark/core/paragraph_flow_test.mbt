///|
test "splits text at paragraph breaks" {
  @test.assert_eq(
    split_paragraph_text("First\n\nSecond"),
    [ParagraphPart::Text("First"), Break, Text("Second")],
  )
  @test.assert_eq(
    split_paragraph_text("First\n  \r\t\nSecond"),
    [ParagraphPart::Text("First"), Break, Text("Second")],
  )
}

///|
test "detects paragraph breaks and clamps headings" {
  @test.assert_eq(has_paragraph_break("a\nb"), false)
  @test.assert_eq(has_paragraph_break("a\n\nb"), true)
  @test.assert_eq(clamp_heading_level(0), 1)
  @test.assert_eq(clamp_heading_level(7), 6)
  @test.assert_eq(clamp_heading_level(3), 3)
}
