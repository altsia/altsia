///|
fn first_collected_error(
  result : Result[String, Array[String]],
) -> String raise {
  guard result is Err(errors) && errors is [first, ..] else {
    fail("expected result to collect errors")
  }
  first
}

///|
fn first_collected_diagnostic(
  result : Result[String, Array[@core.RenderError]],
) -> @core.RenderError raise {
  guard result is Err(errors) && errors is [first, ..] else {
    fail("expected result to collect diagnostics")
  }
  first
}

///|
test "bindings expose stage3 error as structured and displayable" {
  let source = "(div (:class (a) (b)) hi)"

  let raise_result : Result[String, Error] = try? altsia_to_html_raise(source)
  guard raise_result
    is Err(@core.Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~)) else {
    fail("expected Stage3Error::AttributeExpectsAtMostOneValue")
  }
  assert_eq(values, [App("a", []), App("b", [])])
  assert_true(loc is Some(_))

  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("[stage3.lower]"))
  assert_true(first.contains("attribute expects at most one value"))
  assert_true(first.contains(":"))

  let diagnostic = first_collected_diagnostic(
    altsia_to_html_diagnostics(source),
  )
  assert_eq(diagnostic.code, "stage3.attribute-too-many-values")
  assert_eq(diagnostic.phase, "stage3.lower")
  assert_true(diagnostic.loc is Some(_))
  guard diagnostic.source_excerpt is Some(excerpt) else {
    fail("expected source excerpt")
  }
  assert_true(excerpt.contains("(:class (a) (b))"))

  let rendered = altsia_to_html(source)
  assert_true(rendered.contains("attribute expects at most one value"))
}



///|
test "bindings stringify structured template mismatch error" {
  let source = "(λ dup2 (x y) (x)) (dup2 only-one)"
  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("[stage2-etale.expand]"))
  assert_true(first.contains("template arity mismatch"))
  assert_true(first.contains("template=dup2"))
  assert_true(first.contains("expected=2"))
  assert_true(first.contains("got=1"))

  let diagnostic = first_collected_diagnostic(
    altsia_to_html_diagnostics(source),
  )
  assert_eq(diagnostic.code, "stage2-etale.template-arity-mismatch")
  assert_eq(diagnostic.phase, "stage2-etale.expand")
  assert_true(diagnostic.loc is Some(_))
  assert_true(diagnostic.source_excerpt is Some(_))
}

///|
test "bindings stringify structured stage2 function-name error" {
  let source = "((head) body)"
  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("[stage2.elaborate]"))
  assert_true(first.contains("function name must be plain text"))
  let diagnostic = first_collected_diagnostic(
    altsia_to_html_diagnostics(source),
  )
  assert_eq(diagnostic.code, "stage2.function-name-not-text")
  assert_eq(diagnostic.phase, "stage2.elaborate")
  assert_true(diagnostic.loc is Some(_))
  assert_true(diagnostic.source_excerpt is Some(_))
}


///|
test "bindings expose Stage1 parse error with precise loc" {
  let source = "oops"
  let diagnostic = first_collected_diagnostic(
    altsia_to_html_diagnostics(source),
  )
  assert_eq(diagnostic.code, "stage1.unexpected-top-level-token")
  assert_eq(diagnostic.phase, "stage1.parse")
  guard diagnostic.loc is Some(loc) else { fail("expected diagnostic loc") }
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 1)
  guard diagnostic.source_excerpt is Some(excerpt) else {
    fail("expected source excerpt")
  }
  assert_true(excerpt.contains("oops"))

  let first = first_collected_error(altsia_to_html_result(source))
  assert_true(first.contains("[stage1.parse]"))
  assert_true(first.contains("1:1:"))
  assert_true(first.contains("unexpected top-level token"))
}

///|
test "render_error localizes message with language parameter" {
  let source = "oops"
  let zh_diag = first_collected_diagnostic(
    altsia_to_html_diagnostics(source, language="zh-CN"),
  )
  assert_eq(zh_diag.phase, "stage1.parse")
  assert_true(zh_diag.message.contains("顶层出现意外 token"))
  assert_true(zh_diag.source_excerpt is Some(_))

  let zh_message = first_collected_error(
    altsia_to_html_result(source, language="zh-CN"),
  )
  assert_true(zh_message.contains("顶层出现意外 token"))

  let fallback_diag = first_collected_diagnostic(
    altsia_to_html_diagnostics(source, language="xx-YY"),
  )
  assert_true(fallback_diag.message.contains("unexpected top-level token"))

  let es_diag = first_collected_diagnostic(
    altsia_to_html_diagnostics(source, language="es-419"),
  )
  assert_true(es_diag.message.contains("token inesperado en el nivel superior"))

  let ko_fallback_diag = first_collected_diagnostic(
    altsia_to_html_diagnostics(source, language="ko-KR"),
  )
  assert_true(ko_fallback_diag.message.contains("unexpected top-level token"))

  let pt_fallback_diag = first_collected_diagnostic(
    altsia_to_html_diagnostics(source, language="pt"),
  )
  assert_true(pt_fallback_diag.message.contains("unexpected top-level token"))

  let langs = @core.render_error_supported_languages()
  assert_true(langs.contains("en"))
  assert_true(langs.contains("zh-CN"))
  assert_true(langs.contains("ms"))
}
