///|
enum SExpr {
  EText(String)
  EQuote(String)
  EApp(Array[SExpr])
} derive(Eq, Show)

///|
fn strip_loc(node : S) -> SExpr {
  match node {
    Text(s, _) => EText(s)
    Quote(s, _) => EQuote(s)
    App(args, _) => EApp(args.map(strip_loc))
  }
}

///|
fn parse_semantics(source : String) -> Array[SExpr] raise {
  Stage1::parse(source).map(strip_loc)
}

///|
test "Parsing stage 1 per component" {
  assert_eq("(canta per me ne addio)" |> parse_semantics, [
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
    |> parse_semantics,
    [EApp([EQuote("line1\nline2\n")])],
  )
}

///|
test "Parsing stage 1 nested app and escaped parens" {
  let source = "(root a \\(b\\) (child c d))"
  assert_eq(
    source |> parse_semantics,
    [
      EApp([
        EText("root"),
        EText("a (b)"),
        EApp([EText("child"), EText("c d")]),
      ]),
    ],
  )
}

///|
test "Reconstructing stage 1 per component" {
  let source = "(p hello world)"
  assert_eq(source |> Stage1::parse |> to_source, source)

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
