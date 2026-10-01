///|
test "markdown text with inline math renders MathML" {
  let content =
    #|The solution of $x^2 = 2$ is irrational.
  let expected =
    #|<p>The solution of <math xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mrow><msup><mi>x</mi><mn>2</mn></msup><mo>=</mo><mn>2</mn></mrow></semantics></math> is irrational.</p>
  let actual = @parsing.document.parse(@talc.Input::new(content))
    |> Result::unwrap
    |> @backend.render_document(target=@backend.Mathml)
  @test.assert_eq(actual, expected)
}

///|
test "markdown display math renders MathML wrapped in a span" {
  let blocks = [@parsing.DisplayMath("x^2 = 2")]
  let expected =
    #|<span class="math-display" style="display: block; margin: 1em 0; text-align: center"><math xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mstyle scriptlevel="0" displaystyle="true"><msup><mi>x</mi><mn>2</mn></msup><mo>=</mo><mn>2</mn></mstyle></semantics></math></span>
  let actual = @backend.render_document(blocks, target=Mathml)
  @test.assert_eq(actual, expected)
}
