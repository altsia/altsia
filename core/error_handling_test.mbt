///|
test "Stage2 propagates structured function-name error" {
  let source = "((head))"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass)
  guard result is Err(Stage2Error::FunctionNameMustBePlainText(found~, loc~)) else {
    fail("expected Stage2Error::FunctionNameMustBePlainText")
  }
  guard found is App([Text("head", _)], _) else {
    fail("expected found to be app(head)")
  }
  guard loc is Some(error_loc) else {
    fail("expected loc for spanned function-name error")
  }
  assert_eq(error_loc.line, 1)
  assert_eq(error_loc.column, 2)
}

///|
test "Stage2 propagates structured template header errors" {
  let missing_params_result : Result[Array[Term], Error] = try? ("(λ tpl)"
  |> Stage1::parse
  |> Stage2::pass)
  guard missing_params_result
    is Err(Stage2Error::TemplateRequiresNameAndParamList(items~, loc~)) else {
    fail("expected Stage2Error::TemplateRequiresNameAndParamList")
  }
  guard items is [Text("tpl", _)] else {
    fail("expected missing header items to contain tpl")
  }
  guard loc is Some(header_loc) else {
    fail("expected loc for missing template params")
  }
  assert_eq(header_loc.line, 1)
  assert_eq(header_loc.column, 1)

  let non_list_params_result : Result[Array[Term], Error] = try? ("(λ tpl)\n```\nnot-a-list\n```"
  |> Stage1::parse
  |> Stage2::pass)
  guard non_list_params_result
    is Err(Stage2Error::TemplateParamsMustBeList(found~, loc~)) else {
    fail("expected Stage2Error::TemplateParamsMustBeList")
  }
  guard found is QuoteBlock("not-a-list\n", _) else {
    fail("expected non-list params found to be quote")
  }
  guard loc is Some(params_loc) else {
    fail("expected loc for non-list template params")
  }
  assert_eq(params_loc.line, 2)
  assert_eq(params_loc.column, 1)
}

///|
test "Stage2 propagates template-param missing-head with loc" {
  let source = "(λ tpl (() x) (x))"
  let result : Result[Array[Term], Error] = try? (source
  |> Stage1::parse
  |> Stage2::pass)
  guard result
    is Err(Stage2Error::TemplateParamApplicationMissingHead(found~, loc~)) else {
    fail("expected Stage2Error::TemplateParamApplicationMissingHead")
  }
  guard found is App([], _) else {
    fail("expected missing-head found to be empty app")
  }
  guard loc is Some(error_loc) else {
    fail("expected loc for spanned template param missing-head")
  }
  assert_eq(error_loc.line, 1)
  assert_eq(error_loc.column, 9)
}

///|
test "Stage2Etale propagates structured arity mismatch error" {
  let result : Result[Array[Term], Error] = try? ("(λ dup2 (x y) (x)) (dup2 only-one)"
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
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
  guard args is [Text("only-one", _)] else {
    fail("expected mismatch args to contain the call argument")
  }
  guard loc is Some(_) else { fail("expected loc for template arity mismatch") }
}

///|
test "Stage2Etale propagates structured nested-template substitution error" {
  let result : Result[Array[Term], Error] = try? ("(λ outer (x) (λ inner (y) (y)) (x)) (outer ok)"
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Err(
      Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~, loc~)
    ) else {
    fail("expected Stage2EtaleError::NestedTemplateDefinitionInSubstitution")
  }
  guard term is TemplateDefinition("inner", _, _, _) else {
    fail("expected nested template name to be inner")
  }
  guard loc is Some(_) else {
    fail("expected loc for nested template definition")
  }
}

///|
test "Stage3 propagates structured attribute value arity error" {
  let result : Result[Doc, Error] = try? ("(div (:class (a) (b)) hello)"
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> Stage3::pass)
  guard result
    is Err(Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~)) else {
    fail("expected Stage3Error::AttributeExpectsAtMostOneValue")
  }
  guard values is [App("a", [], _), App("b", [], _)] else {
    fail("expected attribute values to keep both terms")
  }
  guard loc is Some(_) else {
    fail("expected loc for attribute value arity error")
  }
}

///|
test "Stage3 returns structured unexpected template-definition error" {
  let result : Result[Doc, Error] = try? ("(λ t (x) (x))"
  |> Stage1::parse
  |> Stage2::pass
  |> Stage3::pass)
  guard result is Err(Stage3Error::UnexpectedTemplateDefinition(term~, loc~)) else {
    fail("expected Stage3Error::UnexpectedTemplateDefinition")
  }
  guard term is TemplateDefinition("t", _, _, _) else {
    fail("expected template definition term")
  }
  guard loc is Some(_) else {
    fail("expected loc for unexpected template definition")
  }
}

///|
test "Stage2Etale returns structured unexpected template-definition error" {
  let result : Result[Array[Term], Error] = try? ("(p (λ t (x) (x)))"
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program)
  guard result
    is Err(
      Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(
        term=found_term,
        loc~
      )
    ) else {
    fail("expected Stage2EtaleError::UnexpectedTemplateDefinitionInExpand")
  }
  guard found_term is TemplateDefinition("t", _, _, _) else {
    fail("expected nested template definition in expansion error")
  }
  guard loc is Some(_) else {
    fail("expected loc for unexpected template definition in expansion")
  }
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

///|
test "Stage1 propagates structured unclosed inline quote error" {
  let source = "(p `hello)"
  let result : Result[Array[S], Error] = try? Stage1::parse(source)
  guard result is Err(Stage1Error::UnclosedQuoteInline(loc~)) else {
    fail("expected Stage1Error::UnclosedQuoteInline")
  }
  assert_eq(loc.start_offset, 3)
  assert_eq(loc.end_offset, source.length())
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 4)
}
