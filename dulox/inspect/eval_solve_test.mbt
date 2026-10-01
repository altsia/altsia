///|
test "solve cubic unity roots renders canonical zero terms" {
  inspect(
    eval_render("\\solve{x^3=1}"),
    content="x₁ = 1, x₂ = ω, x₃ = ω²",
  )
}

///|
test "solve basic quadratics" {
  @test.assert_eq(eval_render("\\solve[x]{x^2+2x+1=0}"), "x₁ = −1")
  @test.assert_eq(
    eval_render("\\solve[x]{x^2-2=0}"),
    "x₁ = √2, x₂ = −√2",
  )
  @test.assert_eq(eval_render("\\solve[x]{x^2+1=0}"), "x₁ = i, x₂ = −i")
  @test.assert_eq(eval_render("\\solve[x]{2x+4=0}"), "x₁ = −2")
  @test.assert_eq(eval_render("\\solve[x]{x^2=0}"), "x₁ = 0")
  @test.assert_eq(
    eval_render("\\solve[x]{x^2+\\frac{1}{2}x+\\frac{1}{16}=0}"),
    "x₁ = -1∕4",
  )
}

///|
test "solve symbolic coefficients" {
  @test.assert_eq(
    eval_render("\\solve[x]{x^2+bx+2=0}"),
    "x₁ = (−b+√(b²−8))∕2, x₂ = (−b−√(b²−8))∕2",
  )
  inspect(
    eval_render("\\solve{ax^2+bx+c=0}", allow_degenerate=true),
    content=(
      #|x₁ = (−b+√(b²−4ac))∕(2a), x₂ = (−b−√(b²−4ac))∕(2a) (a ≠ 0),   x₁ = (−c)∕b (a = 0, b ≠ 0),   ℂ (a = 0, b = 0, c = 0),   ∅ (a = 0, b = 0, c ≠ 0)
    ),
  )
}

///|
test "solve greek variable" {
  @test.assert_eq(
    eval_render("\\solve[\\alpha]{\\alpha^2+1=0}"),
    "α₁ = i, α₂ = −i",
  )
}

///|
test "solve default variable inference" {
  @test.assert_eq(eval_render("\\solve{x^2+2x+1=0}"), "x₁ = −1")
}

///|
test "solve accepts equivalent polynomial syntax" {
  @test.assert_eq(eval_render("\\solve[x]{(x+1)^2=0}"), "x₁ = −1")
  @test.assert_eq(eval_render("\\solve[x]{x+x=0}"), "x₁ = 0")
  @test.assert_eq(eval_render("\\solve[x]{x\\cdot x=0}"), "x₁ = 0")
  @test.assert_eq(eval_render("\\solve[x]{(x+1)^2=4}"), "x₁ = 1, x₂ = −3")
  @test.assert_eq(eval_render("\\solve[x]{0=x-2}"), "x₁ = 2")
}

///|
test "solve real domain rejects complex roots" {
  let nodes = @katex.parse("x^2+1")
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(nodes, options)
  let req = @eval.SolveRequest::{
    expr,
    variable: @eval.SymbolKey::make("x"),
    domain: @eval.Domain::R,
    assumptions: [],
  }
  let result = try! @eval.SolveRequest::solve(req, allow_degenerate=false)
  match result.cases[0].solution {
    @eval.SolutionKind::Empty => ()
    _ => @test.assert_eq(true, false)
  }
}

///|
test "solve result models degenerate polynomial branches" {
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(@katex.parse("ax^2+bx+c"), options)
  let req = @eval.SolveRequest::{
    expr,
    variable: @eval.SymbolKey::make("x"),
    domain: @eval.Domain::C,
    assumptions: [],
  }
  let result = try! @eval.SolveRequest::solve(req, allow_degenerate=true)
  @test.assert_eq(result.cases.length(), 4)
  match
    (
      result.cases[0].solution,
      result.cases[1].solution,
      result.cases[2].solution,
      result.cases[3].solution,
    ) {
    (
      @eval.SolutionKind::Finite(roots),
      @eval.SolutionKind::Finite(linear),
      @eval.SolutionKind::Universal,
      @eval.SolutionKind::Empty,
    ) => {
      @test.assert_eq(roots.length(), 2)
      @test.assert_eq(linear.length(), 1)
    }
    _ => @test.assert_eq(true, false)
  }
}

///|
test "solve real domain keeps rational roots" {
  let nodes = @katex.parse("x^2-2")
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(nodes, options)
  let req = @eval.SolveRequest::{
    expr,
    variable: @eval.SymbolKey::make("x"),
    domain: @eval.Domain::R,
    assumptions: [],
  }
  let result = try! @eval.SolveRequest::solve(req, allow_degenerate=false)
  match result.cases[0].solution {
    @eval.SolutionKind::Finite(roots) => @test.assert_eq(roots.length(), 2)
    _ => @test.assert_eq(true, false)
  }
}

///|
test "solve_univariate emits symbolic leading coefficient condition" {
  let nodes = @katex.parse("ax^2+bx+c")
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(nodes, options)
  let req = @eval.SolveRequest::{
    expr,
    variable: @eval.SymbolKey::make("x"),
    domain: @eval.Domain::C,
    assumptions: [],
  }
  let result = try! @eval.SolveRequest::solve(req, allow_degenerate=false)
  @test.assert_eq(result.cases[0].conditions.length(), 1)
}

///|
test "solve assumptions select compatible symbolic branch" {
  let options = @eval.EvalOptions::make()
  let expr = @eval.lower_expr(@katex.parse("ax^2+bx+c"), options)
  let a = @eval.Symbol(@eval.SymbolKey::make("a"))
  let req = @eval.SolveRequest::{
    expr,
    variable: @eval.SymbolKey::make("x"),
    domain: @eval.Domain::C,
    assumptions: [@eval.Condition::NonZero(a)],
  }
  let result = try! @eval.SolveRequest::solve(req, allow_degenerate=false)
  @test.assert_eq(result.cases.length(), 1)
  @test.assert_eq(result.cases[0].conditions.length(), 0)
}
