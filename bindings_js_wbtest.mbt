///|
test "bindings apply ExternApi text visitor" {
  let source = "(p hello)"
  let extern_api : ExternApi = ExternApi::{ visit_text: s => "[" + s + "]" }

  let rendered = altsia_to_html_with_extern_api(source, extern_api)
  assert_eq(rendered, "<div><p>[hello]</p></div>")

  let raised = altsia_to_html_with_extern_api_raise(source, extern_api)
  assert_eq(raised, "<div><p>[hello]</p></div>")
}
