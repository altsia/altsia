///|
test "kodama bindings build project context from external docs and render html" {
  let source = "(p (ref b.alt))"
  let context_api = ContextApi::{ doc_workspace_path: "a.alt" }
  let project_docs : Array[DocEntry] = [
    { id: "a.alt", content: "(metadata (:title A))" },
    { id: "b.alt", content: "(metadata (:title B))" },
  ]
  let html = kodama_to_html_raise(source, context_api, project_docs)
  assert_eq(html, "<div><p><a href=\"b.alt\" title=\"B [b]\">B</a></p></div>")
}

///|
test "kodama bindings stringify parse error without diagnostics/result wrappers" {
  let source = "oops"
  let context_api = ContextApi::{ doc_workspace_path: "a.alt" }
  let project_docs : Array[DocEntry] = [
    { id: "a.alt", content: "(metadata (:title A))" },
  ]
  let rendered = kodama_to_html(source, context_api, project_docs)
  assert_true(rendered.contains("[stage1.parse]"))
  assert_true(rendered.contains("unexpected top-level token"))
}
