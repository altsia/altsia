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
test "Stage2Etale ignores layout gap text for template arity" {
  let source = "(λ pair (x y) (p (x) (y))) (pair (a) (b))"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Ok([App("p", [App("a", [], _), Text(" ", _), App("b", [], _)], _)]) else {
    fail(
      "expected pair expansion to keep one layout space and pass arity check",
    )
  }
}

///|
test "Stage2Etale merges trailing args into variadic tail param" {
  let source = "(λ card (title content...) (p (title) (content))) (card (hello) (a) (b) (c))"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Ok(
      [
        App(
          "p",
          [
            App("hello", [], _),
            Text(" ", _),
            App("a", [], _),
            Text(" ", _),
            App("b", [], _),
            Text(" ", _),
            App("c", [], _),
          ],
          _
        ),
      ]
    ) else {
    fail("expected variadic tail param to capture trailing args as one splice")
  }
}

///|
test "Stage2Etale binds named argument by (:name value) call syntax" {
  let source = "(λ badge (:class content) (p (:class) (content))) (badge (:class primary) hello)"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Ok([App("p", [Text("primary", _), Text(" ", _), Text("hello", _)], _)]) else {
    fail("expected named :class to bind from (:class primary)")
  }
}

///|
test "Stage2Etale applies named default from (:name default)" {
  let source = "(λ badge ((:class default) content) (p (:class) (content))) (badge hello)"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Ok([App("p", [Text("default", _), Text(" ", _), Text("hello", _)], _)]) else {
    fail("expected :class default to be used when named arg is omitted")
  }
}

///|
test "Stage2Etale treats missing named value as empty text" {
  let source = "(λ badge (:class content) (p before (:class) after (content))) (badge (:class) hello)"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Ok(
      [
        App(
          "p",
          [
            Text("before", _),
            Text(" ", _),
            Text("", _),
            Text(" ", _),
            Text("after", _),
            Text(" ", _),
            Text("hello", _),
          ],
          _
        ),
      ]
    ) else {
    fail("expected (:class) call argument to bind as empty Text(\"\")")
  }
}
