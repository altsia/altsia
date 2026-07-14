///|
test "diagnostic render includes hint after source context" {
  let span : SourceSpan = {
    source_id: Some("docs.sia"),
    line: 2,
    column: 3,
    marker_column: 3,
    line_text: "oops",
  }
  let diagnostic = span.diagnostic(Type, "broken", hint="fix it")
  @test.assert_eq(
    diagnostic.render(),
    "type error at docs.sia:2:3: broken\n2 | oops\n  |   ^\nhint: fix it",
  )
}
