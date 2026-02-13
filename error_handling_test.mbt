///|
fn[T] assert_failure_contains(
  result : Result[T, Error],
  needle : String,
) -> Unit raise {
  guard result is Err(Failure::Failure(message)) && message.contains(needle) else {
    fail("expected failure containing: \{needle}")
  }
}

///|
test "Stage2 propagates invalid function-name error" {
  let bad : S = App(@list.from_array([App(@list.from_array([Text("head")]))]))
  let result : Result[Array[Term], Error] = try? Stage2::pass([bad])
  assert_failure_contains(result, "function name must be plain text")
}

///|
test "Stage2 propagates template header errors" {
  let missing_params : S = App(@list.from_array([Text("λ"), Text("tpl")]))
  let missing_params_result : Result[Array[Term], Error] = try?
    Stage2::pass([missing_params])
  assert_failure_contains(
    missing_params_result,
    "template requires name and param list",
  )

  let non_list_params : S = App(
    @list.from_array([Text("λ"), Text("tpl"), Text("not-a-list"), Text("body")]),
  )
  let non_list_params_result : Result[Array[Term], Error] = try?
    Stage2::pass([non_list_params])
  assert_failure_contains(non_list_params_result, "template params must be a list")
}

///|
test "Stage2Etale propagates arity mismatch error" {
  let terms : Array[Term] = [
    TemplateDefinition("dup2", ["x", "y"], [App("x", [])]),
    App("dup2", [Text("only-one")]),
  ]
  let result : Result[Array[Term], Error] = try?
    Stage2Etale::expand_program(terms)
  assert_failure_contains(result, "template arity mismatch")
}

///|
test "Stage3 propagates attribute value arity error" {
  let terms : Array[Term] = [
    App("div", [App(":class", [App("a", []), App("b", [])]), Text("hello")]),
  ]
  let result : Result[Doc, Error] = try? Stage3::pass(terms)
  assert_failure_contains(result, "attribute expects at most one value")
}

///|
test "bindings expose raise/result/string error handling" {
  let source = "(div (:class (a) (b)) hi)"

  let raise_result : Result[String, Error] = try? altsia_to_html_raise(source)
  assert_failure_contains(raise_result, "attribute expects at most one value")

  let result = altsia_to_html_result(source)
  guard result is Err(errors) && errors is [first, ..] else {
    fail("expected altsia_to_html_result to collect errors")
  }
  assert_true(first.contains("attribute expects at most one value"))

  let rendered = altsia_to_html(source)
  assert_true(rendered.contains("attribute expects at most one value"))
}
