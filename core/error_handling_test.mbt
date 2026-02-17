
///|
test "Stage2 propagates structured function-name error" {
  let bad_head : S = App(@list.from_array([Text("head")]))
  let bad : S = App(@list.from_array([bad_head]))
  let result : Result[Array[Term], Error] = try? Stage2::pass([bad])
  guard result is Err(Stage2Error::FunctionNameMustBePlainText(found~, loc~)) else {
    fail("expected Stage2Error::FunctionNameMustBePlainText")
  }
  assert_eq(found, bad_head)
  assert_eq(loc, None)
}

///|
test "Stage2 propagates structured template header errors" {
  let missing_params : S = App(@list.from_array([Text("λ"), Text("tpl")]))
  let missing_params_result : Result[Array[Term], Error] = try? Stage2::pass([
    missing_params,
  ])
  guard missing_params_result
    is Err(Stage2Error::TemplateRequiresNameAndParamList(items~, loc~)) else {
    fail("expected Stage2Error::TemplateRequiresNameAndParamList")
  }
  assert_eq(items, [Text("tpl")])
  assert_eq(loc, None)

  let non_list_params : S = App(
    @list.from_array([Text("λ"), Text("tpl"), Text("not-a-list"), Text("body")]),
  )
  let non_list_params_result : Result[Array[Term], Error] = try? Stage2::pass([
    non_list_params,
  ])
  guard non_list_params_result
    is Err(Stage2Error::TemplateParamsMustBeList(found~, loc~)) else {
    fail("expected Stage2Error::TemplateParamsMustBeList")
  }
  assert_eq(found, Text("not-a-list"))
  assert_eq(loc, None)
}

///|
test "Stage2Etale propagates structured arity mismatch error" {
  let terms : Array[Term] = [
    TemplateDefinition("dup2", ["x", "y"], [App("x", [])]),
    App("dup2", [Text("only-one")]),
  ]
  let result : Result[Array[Term], Error] = try? Stage2Etale::expand_program(
    terms,
  )
  guard result
    is Err(
      Stage2EtaleError::TemplateArityMismatch(
        template_name~,
        expected~,
        got~,
        args~,
        loc~
      )
    ) else {
    fail("expected Stage2EtaleError::TemplateArityMismatch")
  }
  assert_eq(template_name, "dup2")
  assert_eq(expected, 2)
  assert_eq(got, 1)
  assert_eq(args, [Text("only-one")])
  assert_eq(loc, None)
}

///|
test "Stage2Etale propagates structured nested-template substitution error" {
  let nested : Term = TemplateDefinition("inner", ["y"], [App("y", [])])
  let terms : Array[Term] = [
    TemplateDefinition("outer", ["x"], [nested, App("x", [])]),
    App("outer", [Text("ok")]),
  ]
  let result : Result[Array[Term], Error] = try? Stage2Etale::expand_program(
    terms,
  )
  guard result
    is Err(
      Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~, loc~)
    ) else {
    fail("expected Stage2EtaleError::NestedTemplateDefinitionInSubstitution")
  }
  assert_eq(term, nested)
  assert_eq(loc, None)
}

///|
test "Stage3 propagates structured attribute value arity error" {
  let terms : Array[Term] = [
    App("div", [App(":class", [App("a", []), App("b", [])]), Text("hello")]),
  ]
  let result : Result[Doc, Error] = try? Stage3::pass(terms)
  guard result
    is Err(Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~)) else {
    fail("expected Stage3Error::AttributeExpectsAtMostOneValue")
  }
  assert_eq(values, [App("a", []), App("b", [])])
  assert_eq(loc, None)
}

///|
test "Stage3 returns structured unexpected template-definition error" {
  let terms : Array[Term] = [TemplateDefinition("t", ["x"], [App("x", [])])]
  let result : Result[Doc, Error] = try? Stage3::pass(terms)
  guard result is Err(Stage3Error::UnexpectedTemplateDefinition(term~, loc~)) else {
    fail("expected Stage3Error::UnexpectedTemplateDefinition")
  }
  assert_eq(term, TemplateDefinition("t", ["x"], [App("x", [])]))
  assert_eq(loc, None)
}

///|
test "Stage2Etale returns structured unexpected template-definition error" {
  let env : Env = @hashmap.HashMap::new()
  let input_term : Term = TemplateDefinition("t", ["x"], [App("x", [])])
  let result : Result[Array[Term], Error] = try? expand(env, input_term)
  guard result
    is Err(
      Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(
        term=found_term,
        loc~
      )
    ) else {
    fail("expected Stage2EtaleError::UnexpectedTemplateDefinitionInExpand")
  }
  assert_eq(found_term, input_term)
  assert_eq(loc, None)
}


///|
test "Stage1 propagates structured unexpected top-level token error" {
  let result : Result[Array[S], Error] = try? Stage1::parse("oops")
  guard result is Err(Stage1Error::UnexpectedTopLevelToken(token~, loc~)) else {
    fail("expected Stage1Error::UnexpectedTopLevelToken")
  }
  assert_eq(token, "o")
  assert_eq(loc.start_offset, 0)
  assert_eq(loc.end_offset, 1)
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 1)
}

///|
test "Stage1 propagates structured unclosed application error" {
  let source = "(p hello"
  let result : Result[Array[S], Error] = try? Stage1::parse(source)
  guard result is Err(Stage1Error::UnclosedApplication(loc~)) else {
    fail("expected Stage1Error::UnclosedApplication")
  }
  assert_eq(loc.start_offset, 0)
  assert_eq(loc.end_offset, source.length())
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 1)
}
