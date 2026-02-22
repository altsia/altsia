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
  assert_eq(indexed.metadata.named_args.length(), 2)
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
    { id: "a.alt", content: "(metadata (:title A))" },
    { id: "b.alt", content: "(metadata (:title B) (:parent a.alt))" },
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
    { id: "a.alt", content: "(metadata (:title A))" },
    { id: "b.alt", content: "(metadata (:title B))" },
  ])
  let terms = "(p (ref b.alt))" |> @core.Stage1::parse |> @core.Stage2::pass
  guard terms
    is [@core.Term::App("p", [@core.Term::App("ref", ref_args, _)], _)] else {
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
test "Forester resolves relative ref target metadata from current doc id" {
  let ctx = forester_build_project_context([
    { id: "notes/a.alt", content: "(metadata (:title A))" },
    { id: "notes/b.alt", content: "(metadata (:title B))" },
  ])
  let terms = "(p (ref ./b.alt))" |> @core.Stage1::parse |> @core.Stage2::pass
  guard terms
    is [@core.Term::App("p", [@core.Term::App("ref", ref_args, _)], _)] else {
    fail("expected p(ref ./b.alt)")
  }
  guard
    ctx.resolve_ref_target_metadata(ref_args, current_doc_id="notes/a.alt")
    is Some(meta) else {
    fail("expected target metadata for notes/b.alt")
  }
  guard meta.get("title") is Some(title) else {
    fail("expected :title metadata in target")
  }
  guard title.values is [@core.Term::Text("B", _)] else {
    fail("expected title B")
  }
}

///|
fn forester_pass_with_context(
  source : String,
  ctx : ProjectContext,
  current_doc_id : String,
) -> String raise {
  parse_terms_for_forester(source)
  |> @core.Stage2Extern::rewrite_apps(ctx.to_forester_rewriter(current_doc_id))
  |> @core.Stage3::pass
  |> @core.Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> @core.MarkdownAbbrev::desugar
  |> @core.Html::to_string
}

///|
test "Forester pass with context keeps current rendering behavior" {
  let source = "(p (ref b.alt))"
  let ctx = forester_build_project_context([
    { id: "b.alt", content: "(metadata (:title B))" },
  ])
  let html = forester_pass_with_context(source, ctx, "a.alt")
  assert_eq(
    html,
    "<div><p><span class=\"link local\"><a href=\"b.alt\" title=\"B [b]\">B</a></span></p></div>",
  )
}

///|
test "Forester pass with context keeps explicit ref text over target title" {
  let source = "(p (ref (:text Read B) b.alt))"
  let ctx = forester_build_project_context([
    { id: "b.alt", content: "(metadata (:title B))" },
  ])
  let html = forester_pass_with_context(source, ctx, "a.alt")
  assert_eq(
    html,
    "<div><p><span class=\"link local\"><a href=\"b.alt\" title=\"B [b]\">Read B</a></span></p></div>",
  )
}

///|
test "Forester pass resolves relative ref target against current doc id" {
  let source = "(p (ref ./b.alt))"
  let ctx = forester_build_project_context([
    { id: "notes/b.alt", content: "(metadata (:title B))" },
  ])
  let html = forester_pass_with_context(source, ctx, "notes/a.alt")
  assert_eq(
    html,
    "<div><p><span class=\"link local\"><a href=\"./b.alt\" title=\"B [notes/b]\">B</a></span></p></div>",
  )
}

///|
test "Forester pass resolves parent relative ref target against current doc id" {
  let source = "(p (ref ../b.alt))"
  let ctx = forester_build_project_context([
    { id: "b.alt", content: "(metadata (:title B))" },
  ])
  let html = forester_pass_with_context(source, ctx, "notes/a.alt")
  assert_eq(
    html,
    "<div><p><span class=\"link local\"><a href=\"../b.alt\" title=\"B [b]\">B</a></span></p></div>",
  )
}

///|
test "Forester pass rewrites metadata app into summary structure" {
  let source = "(metadata (:title Demo) (:taxon Lemma) (:id demo-1))"
  let ctx = forester_build_project_context([
    { id: "demo.alt", content: source },
  ])
  let html = forester_pass_with_context(source, ctx, "demo.alt")
  assert_eq(
    html,
    "<div><summary><header><h1><span class=\"taxon\">Lemma</span>Demo</h1><div class=\"metadata\"><ul><li class=\"meta-item\">id: demo-1</li></ul></div></header></summary></div>",
  )
}

///|
test "Forester metadata summary omits metadata list when only fancy keys exist" {
  let source = "(metadata (:title Demo) (:taxon Lemma))"
  let ctx = forester_build_project_context([
    { id: "demo.alt", content: source },
  ])
  let html = forester_pass_with_context(source, ctx, "demo.alt")
  assert_eq(
    html,
    "<div><summary><header><h1><span class=\"taxon\">Lemma</span>Demo</h1></header></summary></div>",
  )
}
