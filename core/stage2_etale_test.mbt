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

///|
test "Stage2Etale rewrite_apps exposes app args for external api integration" {
  let source = "(p before (read alpha beta) after)"
  let doc = source
    |> Stage1::parse
    |> Stage2::pass
    |> Stage2Etale::expand_program
    |> Stage2Etale::rewrite_apps((name, args, loc) => {
      match name {
        "read" => [Text("extern-read:\{args.length()}", loc)]
        _ => [App(name, args, loc)]
      }
    })
    |> Stage3::pass
  assert_eq(doc, [
    Block(Paragraph([Text("before"), Text("extern-read:1"), Text("after")])),
  ])
}
