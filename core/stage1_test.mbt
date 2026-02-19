///|
test "Parsing stage 1 per component" {
  assert_eq("(canta per me ne addio)" |> Stage1::parse_semantics, [
    EApp([EText("canta"), EText("per me ne addio")]),
  ])
  assert_eq(
    (
      #|()
      #|```
      #|line1
      #|line2
      #|```
    )
    |> Stage1::parse_semantics,
    [EApp([EQuote("line1\nline2\n")])],
  )
  assert_eq("(p `inline value` tail)" |> Stage1::parse_semantics, [
    EApp([EText("p"), EQuoteInline("inline value"), EText("tail")]),
  ])
  assert_eq("(p `line1\nline2` tail)" |> Stage1::parse_semantics, [
    EApp([EText("p"), EQuoteInline("line1\nline2"), EText("tail")]),
  ])
  assert_eq(
    (
      #|kd```
      #|line1
      #|line2
      #|```
    )
    |> Stage1::parse_semantics,
    [EApp([EText("kd"), EQuote("line1\nline2\n")])],
  )
  assert_eq("f`inline value`" |> Stage1::parse_semantics, [
    EApp([EText("f"), EQuoteInline("inline value")]),
  ])
  assert_eq("(f`inline value`)" |> Stage1::parse_semantics, [
    EApp([EText("f"), EQuoteInline("inline value")]),
  ])
  assert_eq("(p f`inline value` tail)" |> Stage1::parse_semantics, [
    EApp([
      EText("p"),
      EApp([EText("f"), EQuoteInline("inline value")]),
      EText("tail"),
    ]),
  ])
}

///|
test "Parsing stage 1 nested app and escaped parens" {
  let source = "(root a \\(b\\) (child c d))"
  assert_eq(source |> Stage1::parse_semantics, [
    EApp([EText("root"), EText("a (b)"), EApp([EText("child"), EText("c d")])]),
  ])
}

///|
test "Stage1 to_source preserves tight and space boundaries between app args" {
  let source = "(a b (c) d)"
  assert_eq(source |> Stage1::parse |> to_source, source)
  let comma_source = "(a (b) ,(c) ,(d))"
  assert_eq(comma_source |> Stage1::parse |> to_source, comma_source)
  assert_eq("(a b(c))" |> Stage1::parse |> to_source, "(a b(c))")
  assert_eq("(x (a) (b),(c))" |> Stage1::parse |> to_source, "(x (a) (b),(c))")
  let cjk_tight = "(p (_ 寻)(_ 觅)(_ 冷)(_ 清))"
  assert_eq(cjk_tight |> Stage1::parse |> to_source, cjk_tight)
}

///|
test "Reconstructing stage 1 per component" {
  let source = "(p hello world)"
  assert_eq(source |> Stage1::parse |> to_source, source)
  let inline_source = "(p head `inline value` tail)"
  assert_eq(inline_source |> Stage1::parse |> to_source, inline_source)
  assert_eq("f`inline value`" |> Stage1::parse |> to_source, "(f `inline value`)")
  assert_eq(
    "(p f`inline value` tail)" |> Stage1::parse |> to_source,
    "(p (f `inline value`) tail)",
  )
  let block_sugar_source =
    #|kd```
    #|quote line
    #|```
  let block_canonical =
    #|(kd)
    #|```
    #|quote line
    #|```
  assert_eq(block_sugar_source |> Stage1::parse |> to_source, block_canonical)

  let source =
    #|(p line-1
    #|   line-2)
    #|```
    #|quote line
    #|```
  assert_eq(source |> Stage1::parse |> to_source, source)
}

///|
test "Reconstructing stage 1 with mixed nodes" {
  let source =
    #|(p lead (a one two) tail)
    #|
    #|(q x y z)
    #|
    #|(_ around (~ middle) end)
  let reconstructed = source |> Stage1::parse |> to_source
  assert_eq(reconstructed, source)
}
