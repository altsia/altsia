///|
fn first_collected_error(result : Result[String, Array[String]]) -> String raise {
  guard result is Err(errors) && errors is [first, ..] else {
    fail("expected result to collect errors")
  }
  first
}

///|
test "Stage2 propagates structured function-name error" {
  let bad_head : S = App(@list.from_array([Text("head")]))
  let bad : S = App(@list.from_array([bad_head]))
  let result : Result[Array[Term], Error] = try? Stage2::pass([bad])
  guard result is Err(Stage2Error::FunctionNameMustBePlainText(found~)) else {
    fail("expected Stage2Error::FunctionNameMustBePlainText")
  }
  assert_eq(found, bad_head)
}

///|
test "Stage2 propagates structured template header errors" {
  let missing_params : S = App(@list.from_array([Text("λ"), Text("tpl")]))
  let missing_params_result : Result[Array[Term], Error] = try?
    Stage2::pass([missing_params])
  guard missing_params_result is Err(
    Stage2Error::TemplateRequiresNameAndParamList(items~),
  ) else {
    fail("expected Stage2Error::TemplateRequiresNameAndParamList")
  }
  assert_eq(items, [Text("tpl")])

  let non_list_params : S = App(
    @list.from_array([Text("λ"), Text("tpl"), Text("not-a-list"), Text("body")]),
  )
  let non_list_params_result : Result[Array[Term], Error] = try?
    Stage2::pass([non_list_params])
  guard non_list_params_result is Err(
    Stage2Error::TemplateParamsMustBeList(found~),
  ) else {
    fail("expected Stage2Error::TemplateParamsMustBeList")
  }
  assert_eq(found, Text("not-a-list"))
}

///|
test "Stage2Etale propagates structured arity mismatch error" {
  let terms : Array[Term] = [
    TemplateDefinition("dup2", ["x", "y"], [App("x", [])]),
    App("dup2", [Text("only-one")]),
  ]
  let result : Result[Array[Term], Error] = try?
    Stage2Etale::expand_program(terms)
  guard result is Err(
    Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected~,
      got~,
      args~,
    ),
  ) else {
    fail("expected Stage2EtaleError::TemplateArityMismatch")
  }
  assert_eq(template_name, "dup2")
  assert_eq(expected, 2)
  assert_eq(got, 1)
  assert_eq(args, [Text("only-one")])
}

///|
test "Stage2Etale propagates structured nested-template substitution error" {
  let nested : Term = TemplateDefinition("inner", ["y"], [App("y", [])])
  let terms : Array[Term] = [
    TemplateDefinition("outer", ["x"], [nested, App("x", [])]),
    App("outer", [Text("ok")]),
  ]
  let result : Result[Array[Term], Error] = try?
    Stage2Etale::expand_program(terms)
  guard result is Err(
    Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~),
  ) else {
    fail("expected Stage2EtaleError::NestedTemplateDefinitionInSubstitution")
  }
  assert_eq(term, nested)
}

///|
test "Stage3 propagates structured attribute value arity error" {
  let terms : Array[Term] = [
    App("div", [App(":class", [App("a", []), App("b", [])]), Text("hello")]),
  ]
  let result : Result[Doc, Error] = try? Stage3::pass(terms)
  guard result is Err(Stage3Error::AttributeExpectsAtMostOneValue(values~)) else {
    fail("expected Stage3Error::AttributeExpectsAtMostOneValue")
  }
  assert_eq(values, [App("a", []), App("b", [])])
}

///|
test "bindings expose stage3 error as structured and displayable" {
  let source = "(div (:class (a) (b)) hi)"

  let raise_result : Result[String, Error] = try? altsia_to_html_raise(source)
  guard raise_result is Err(
    Stage3Error::AttributeExpectsAtMostOneValue(values~),
  ) else {
    fail("expected Stage3Error::AttributeExpectsAtMostOneValue")
  }
  assert_eq(values, [App("a", []), App("b", [])])

  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("attribute expects at most one value"))

  let rendered = altsia_to_html(source)
  assert_true(rendered.contains("attribute expects at most one value"))
}

///|
test "bindings stringify structured template mismatch error" {
  let source = "(λ dup2 (x y) (x)) (dup2 only-one)"
  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("template arity mismatch"))
  assert_true(first.contains("template=dup2"))
  assert_true(first.contains("expected=2"))
  assert_true(first.contains("got=1"))
}

///|
test "bindings stringify structured stage2 function-name error" {
  let source = "((head) body)"
  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("function name must be plain text"))
}
