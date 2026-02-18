///|
test "Stage2Etale expands templates into Stage3 doc" {
  let source = "(λ dup2 (x) (x) (x)) (p (dup2 hello))"
  let doc = source
    |> Stage1::parse
    |> Stage2::pass
    |> Stage2Etale::expand_program
    |> Stage3::pass
  assert_eq(doc, [Block(Paragraph([Text("hello"), Text("hello")]))])
}

