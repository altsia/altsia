///|
test "link emits final url and records graph edges" {
  let project = compile_ok([
    source("index.alt", "(meta (:asback true))See (link `about.alt` About)."),
    source("about.alt", "(meta (:asref true :title `About page`))About."),
  ])
  let index = project.trees[0]
  let about = project.trees[1]
  @test.assert_eq(index.html, "<p>See <a href=\"about.html\">About</a>.</p>")
  @test.assert_eq(index.references, [slug("about")])
  @test.assert_eq(about.backlinks, [slug("index")])
}

///|
test "link fallback uses rich target title" {
  let project = compile_ok([
    source("index.alt", "See (link `about.alt`)."),
    source(
      "about.alt", "(let heading (_ (em About)))(meta (:title (heading)))About.",
    ),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<p>See <a href=\"about.html\"><em>About</em></a>.</p>",
  )
}

///|
test "dangling local link is non fatal in normal build" {
  let project = compile_ok([
    source("index.alt", "See (link `missing.alt` Missing)."),
  ])
  @test.assert_eq(project.diagnostics.length(), 1)
  @test.assert_eq(project.missing_targets.length(), 1)
  @test.assert_eq(project.missing_targets[0], {
    source: "index.alt",
    target: "missing.alt",
    kind: LocalLink,
  })
  @test.assert_eq(
    project.trees[0].html,
    "<p>See <a href=\"#\" data-missing-target=\"missing.alt\">Missing</a>.</p>",
  )
}

///|
test "strict check fails on dangling local link" {
  match
    check_project(
      Project::new("", [
        source("index.alt", "See (link `missing.alt` Missing)."),
      ]),
    ) {
    Ok(_) => abort("expected strict dangling link failure")
    Err(error) =>
      @test.assert_eq(error.message, "dangling local link: missing.alt")
  }
}

///|
test "embed expands target content and records inferred parent" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt`)"),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<div class=\"embed\" data-tree=\"child\"><p>Child.</p></div>",
  )
  @test.assert_eq(project.trees[1].parent, Some(slug("index")))
}

///|
test "preview snapshot returns html diagnostics and transitive dependencies" {
  let snapshot : ProjectSnapshot = {
    root: "",
    open_file: Some("index.alt"),
    sources: [
      source("index.alt", "(embed `child.alt`)"),
      source(
        "child.alt", "(use `lib.sia`)Child (lib.value). (link `missing.alt` Missing)",
      ),
      source("lib.sia", "(let value `ok`)"),
    ],
  }
  match preview_snapshot(snapshot, "index.alt") {
    Err(error) => abort(error.render())
    Ok(preview) => {
      @test.assert_eq(preview.entry_tree_slug, slug("index"))
      @test.assert_eq(preview.diagnostics.length(), 1)
      @test.assert_eq(preview.missing_targets.length(), 1)
      @test.assert_eq(preview.dependencies, [
        { source: "index.alt", target: "child.alt", kind: Embed },
        { source: "child.alt", target: "lib.sia", kind: UseLibrary },
      ])
      @test.assert_eq(
        preview.html.contains("<div class=\"embed\" data-tree=\"child\">"),
        true,
      )
    }
  }
}

///|
test "explicit parent overrides inferred parent" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt`)"),
    source("child.alt", "(meta (:parent `root`))Child."),
  ])
  @test.assert_eq(project.trees[1].parent, Some(slug("root")))
}

///|
test "cyclic embed reports full chain" {
  match
    compile_project(
      Project::new("", [
        source("a.alt", "(embed `b.alt`)"),
        source("b.alt", "(embed `a.alt`)"),
      ]),
    ) {
    Ok(_) => abort("expected cyclic embed")
    Err(error) => {
      @test.assert_eq(error.message, "cyclic embed")
      @test.assert_eq(error.hint, Some("a -> b -> a"))
    }
  }
}
