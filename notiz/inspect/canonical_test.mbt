///|
test "canonical inline math expands macros and wraps in delimiters" {
  let blocks = [@parsing.Paragraph([@parsing.InlineMath("\\def\\foo{x}\\foo")])]
  let actual = @backend.render_document(blocks, target=@backend.Canonical)
  @test.assert_eq(actual, "<p>$x$</p>")
}

///|
test "canonical display math folds styled fractions" {
  let blocks = [@parsing.DisplayMath("\\frac{a}{b}")]
  let actual = @backend.render_document(blocks, target=@backend.Canonical)
  @test.assert_eq(actual, "$$\\dfrac{a}{b}$$")
}

///|
test "canonical inline math evaluates \\eval" {
  let blocks = [@parsing.Paragraph([@parsing.InlineMath("\\eval{1+2}")])]
  let actual = @backend.render_document(blocks, target=@backend.Canonical)
  @test.assert_eq(actual, "<p>${3}$</p>")
}

///|
test "canonical display math keeps the display style prefix" {
  let blocks = [@parsing.DisplayMath("\\sum_{i=1}^n i")]
  let actual = @backend.render_document(blocks, target=@backend.Canonical)
  @test.assert_eq(actual, "$$\\displaystyle \\sum^n_{i=1}i$$")
}
