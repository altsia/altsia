///|
/// Canonical form of the normalized expression parsed from `source`.
fn canonical(source : String) -> String raise {
  let nodes = @katex.parse(source)
  let expr = @eval.lower_expr(nodes, @eval.EvalOptions::make())
  let expr = @eval.normalize(expr, @eval.EvalOptions::make())
  expr.to_canonical_string()
}

///|
fn eval_render(
  source : String,
  allow_degenerate? : Bool = false,
) -> String raise @katex.ParseFailure {
  @unicode.render(@eval.parse(source, allow_degenerate~))
}

///|
test "eval basic arithmetic" {
  @test.assert_eq(eval_render("\\eval{1+3}"), "4")
  @test.assert_eq(eval_render("\\eval{2+3*4}"), "14")
  @test.assert_eq(eval_render("\\eval{2^3}"), "8")
  @test.assert_eq(eval_render("\\eval{2(3+x)}"), "2x + 6")
  @test.assert_eq(eval_render("\\eval{2x+3x}"), "5x")
  @test.assert_eq(eval_render("\\eval{x+x*x}"), "x² + x")
  @test.assert_eq(eval_render("\\eval{(x+1)^2}"), "x² + 2x + 1")
  @test.assert_eq(eval_render("\\eval{\\frac{6}{3}}"), "2")
  @test.assert_eq(eval_render("\\eval{x-3}"), "x − 3")
  @test.assert_eq(eval_render("\\eval{-2x}"), "−2x")
  @test.assert_eq(eval_render("\\eval{x^n}"), "xⁿ")
  @test.assert_eq(eval_render("\\eval{x^{\\frac{1}{2}}}"), "x^(1∕2)")
  @test.assert_eq(eval_render("\\eval{\\sqrt{4}}"), "√4")
  @test.assert_eq(eval_render("\\eval{\\sqrt[3]{x}}"), "³√x")
}

///|
test "eval canonical forms" {
  @test.assert_eq(canonical("1+3"), "N4")
  @test.assert_eq(canonical("x+x"), "M(N2, Sx)")
  @test.assert_eq(canonical("x*x"), "P(Sx, 2)")
  @test.assert_eq(canonical("x^n"), "G(Sx, Sn)")
  @test.assert_eq(canonical("x^{2+3}"), "P(Sx, 5)")
  @test.assert_eq(canonical("\\sqrt{x}"), "R(N2, Sx)")
  @test.assert_eq(canonical("\\sqrt[n]{x}"), "R(Sn, Sx)")
  @test.assert_eq(canonical("x+x*x"), "A(P(Sx, 2), Sx)")
  @test.assert_eq(canonical("(x+1)*(x+1)"), "A(P(Sx, 2), M(N2, Sx), N1)")
  @test.assert_eq(canonical("2x+3x"), "M(N5, Sx)")
  @test.assert_eq(canonical("0*x"), "N0")
  @test.assert_eq(canonical("x*1"), "Sx")
  @test.assert_eq(canonical("x^0"), "N1")
  @test.assert_eq(canonical("x-x"), "N0")
  @test.assert_eq(canonical("x+2x"), "M(N3, Sx)")
  @test.assert_eq(canonical("\\alpha+\\alpha"), "M(N2, S\\alpha)")
  @test.assert_eq(canonical("\\frac{4}{2}"), "N2")
  @test.assert_eq(canonical("2^{10}"), "N1024")
}

///|
test "eval decimal literals are rejected" {
  @test.assert_raise(() => @eval.parse("\\eval{2.14}", allow_degenerate=false))
}

///|
test "eval integer overflow is rejected" {
  @test.assert_raise(() => @eval.parse("\\eval{2^{31}}", allow_degenerate=false))
}

///|
test "eval macro scope" {
  @test.assert_eq(eval_render("\\def\\y{x}\\eval{x+\\y}"), "2x")
  @test.assert_eq(eval_render("\\gdef\\y{x}\\eval{2\\y}"), "2x")
  @test.assert_eq(eval_render("\\edef\\y{1+2}\\eval{\\y+1}"), "4")
  @test.assert_eq(eval_render("\\eval{\\eval{1+2}+3}"), "6")
}

///|
test "eval strict mode lowers roots" {
  let nodes = @katex.parse("1+\\sqrt{2}")
  let strict = @eval.EvalOptions::make(mode=Strict)
  let normalized = @eval.normalize(@eval.lower_expr(nodes, strict), strict)
  let constant_last = match normalized {
    @eval.Add(children) =>
      children.length() == 2 && children[1] is @eval.Integer(_)
    _ => false
  }
  @test.assert_eq(constant_last, true)
}

///|
test "roots reject nonpositive concrete indices" {
  let options = @eval.EvalOptions::make(mode=Strict)
  @test.assert_raise(() => {
    let _ = @eval.lower_expr(@katex.parse("\\sqrt[0]{x}"), options)
  })
}

///|
test "eval normalization enforces explicit budgets" {
  let term_limited = @eval.EvalOptions::make(max_terms=1)
  let expression = @eval.lower_expr(@katex.parse("x+y"), term_limited)
  @test.assert_raise(() => {
    let _ = @eval.normalize(expression, term_limited)
  })

  let rewrite_limited = @eval.EvalOptions::make(max_rewrite_steps=0)
  @test.assert_raise(() => {
    let _ = @eval.normalize(@eval.Integer(1), rewrite_limited)
  })
}

///|
test "eval normalization divides every polynomial coefficient exactly" {
  @test.assert_eq(canonical("\\frac{2x+4}{2}"), "A(Sx, N2)")
}

///|
test "eval normalize is idempotent" {
  for source in ["1+3", "x+x*x", "(x+1)^2", "2x+3x", "x-x"] {
    let nodes = @katex.parse(source)
    let options = @eval.EvalOptions::make()
    let expr = @eval.lower_expr(nodes, options)
    let once = @eval.normalize(expr, options)
    let twice = @eval.normalize(once, options)
    @test.assert_eq(twice, once)
  }
}

///|
test "eval partial mode keeps residuals separate" {
  let nodes = @katex.parse("1+2+\\sin(y)")
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(nodes, options)
  let normalized = @eval.normalize(expr, options)
  let is_sum_of_two = match normalized {
    @eval.Add(children) => children.length() == 2
    _ => false
  }
  @test.assert_eq(is_sum_of_two, true)
}

///|
test "eval normalization expands opaque factors" {
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(@katex.parse("(x+\\sin(y))^2"), options)
  let normalized = @eval.normalize(expr, options)
  let has_three_terms = match normalized {
    @eval.Add(children) => children.length() == 3
    _ => false
  }
  @test.assert_eq(has_three_terms, true)
}
