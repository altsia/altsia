///|
test "Forester indexes top-level metadata into named entries" {
  let source =
    #|(metadata (:title Demo) (:id demo-1))
    #|
    #|(p body)
  let indexed = forester_index_document("demo-1.alt", source)
  assert_eq(indexed.doc_id, "demo-1.alt")
  assert_eq(indexed.slug, "demo-1")
  assert_eq(indexed.title, "Demo")
  assert_eq(indexed.title_with_slug(), "Demo [demo-1]")
  assert_eq(indexed.metadata.named.length(), 2)
  guard indexed.metadata.get("title") is Some(title) else {
    fail("expected :title metadata")
  }
  guard title.values is [@core.Term::Text("Demo", _)] else {
    fail("expected :title value to be Demo")
  }
  guard indexed.metadata.get(":id") is Some(doc_id_meta) else {
    fail("expected :id metadata")
  }
  guard doc_id_meta.values is [@core.Term::Text("demo-1", _)] else {
    fail("expected :id value to be demo-1")
  }
}

///|
test "Forester builds project context and resolves metadata by doc id" {
  let ctx = forester_build_project_context([
    ("a.alt", "(metadata (:title A))"),
    ("b.alt", "(metadata (:title B) (:parent a.alt))"),
  ])
  guard ctx.get_metadata("b.alt") is Some(meta_b) else {
    fail("expected metadata for b.alt")
  }
  guard meta_b.get("parent") is Some(parent) else {
    fail("expected :parent metadata for b.alt")
  }
  guard parent.values is [@core.Term::Text("a.alt", _)] else {
    fail("expected parent value a.alt")
  }
  assert_eq(ctx.get_metadata("missing.alt"), None)
}

///|
test "Forester project context resolves ref target metadata from ref args" {
  let ctx = forester_build_project_context([
    ("a.alt", "(metadata (:title A))"),
    ("b.alt", "(metadata (:title B))"),
  ])
  let terms = "(p (ref b.alt))"
    |> @core.Stage1::parse
    |> @core.Stage2::pass
  guard terms is [@core.Term::App("p", [@core.Term::App("ref", ref_args, _)], _)] else {
    fail("expected p(ref b.alt)")
  }
  guard ctx.resolve_ref_target_metadata(ref_args) is Some(meta) else {
    fail("expected target metadata for b.alt")
  }
  guard meta.get("title") is Some(title) else {
    fail("expected :title metadata in target")
  }
  guard title.values is [@core.Term::Text("B", _)] else {
    fail("expected title B")
  }
}

///|
test "Forester pass with context keeps current rendering behavior" {
  let source = "(p (ref b.alt))"
  let ctx = forester_build_project_context([("b.alt", "(metadata (:title B))")])
  let html = forester_pass_with_context(source, ctx, "a.alt")
  assert_eq(html, "<div><p><a href=\"b.alt\" title=\"B [b]\">B</a></p></div>")
}

///|
test "Forester pass with context keeps explicit ref text over target title" {
  let source = "(p (ref (:text Read B) b.alt))"
  let ctx = forester_build_project_context([("b.alt", "(metadata (:title B))")])
  let html = forester_pass_with_context(source, ctx, "a.alt")
  assert_eq(
    html,
    "<div><p><a href=\"b.alt\" title=\"B [b]\">Read B</a></p></div>",
  )
}
