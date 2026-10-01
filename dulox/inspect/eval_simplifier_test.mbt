///|
test "solve simplifier handles principal radical rules" {
  let product = @eval.Root(
    index=@eval.two,
    @eval.Mul([@eval.Integer(12), @eval.Symbol(@eval.SymbolKey::make("x"))]),
  )
  let cube = @eval.Root(index=@eval.Integer(3), @eval.Integer(-27))
  let rational = @eval.Root(
    index=@eval.two,
    @eval.Div(@eval.Integer(8), @eval.Integer(18)),
  )
  @test.assert_eq(
    product.simplify_solve(@eval.Domain::C),
    @eval.Mul([
      @eval.Integer(2),
      @eval.Root(
        index=@eval.two,
        @eval.Mul([@eval.Integer(3), @eval.Symbol(@eval.SymbolKey::make("x"))]),
      ),
    ]),
  )
  @test.assert_eq(cube.simplify_solve(@eval.Domain::C), @eval.Integer(-3))
  @test.assert_eq(
    rational.simplify_solve(@eval.Domain::R).to_canonical_string(),
    "Q(2/3)",
  )
}

///|
test "solve simplifier bounds complex power expansion" {
  let value = @eval.EvalExpr::Complex(@eval.Integer(1), @eval.Integer(1))
  @test.assert_eq(
    @eval.IntPow(value, 2).simplify_solve(@eval.Domain::C),
    @eval.EvalExpr::Complex(@eval.Integer(0), @eval.Integer(2)),
  )
  @test.assert_eq(
    @eval.IntPow(value, 17).simplify_solve(@eval.Domain::C),
    @eval.IntPow(value, 17),
  )
}

///|
test "solve simplifier canonicalizes roots of unity" {
  let root = @eval.RootOfUnity(order=@eval.Integer(3), power=@eval.Integer(-1))
  @test.assert_eq(
    root.simplify_solve(@eval.Domain::C),
    @eval.RootOfUnity(order=@eval.Integer(3), power=@eval.Integer(2)),
  )
  @test.assert_eq(
    @eval.IntPow(root, 2).simplify_solve(@eval.Domain::C),
    @eval.RootOfUnity(order=@eval.Integer(3), power=@eval.Integer(1)),
  )
  @test.assert_eq(
    @eval.Mul([
      @eval.RootOfUnity(order=@eval.Integer(3), power=@eval.Integer(1)),
      @eval.RootOfUnity(order=@eval.Integer(3), power=@eval.Integer(2)),
    ]).simplify_solve(@eval.Domain::C),
    @eval.Integer(1),
  )
}
