///|
test "link emits final url and records source file dependencies" {
  let project = compile_ok([
    source("index.alt", "(meta (:asback true))See (link `about.alt` About)."),
    source("about.alt", "(meta (:asref true :title `About page`))About."),
  ])
  let index = project.trees[0]
  let about = project.trees[1]
  @test.assert_eq(
    index.html,
    "<p>See <a href=\"about.html\">About</a>.</p><footer class=\"tree-footer\"><section class=\"tree-references\"><h2>References</h2><ol><li><a href=\"about.html\">About page</a></li></ol></section></footer>",
  )
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
test "link inside markup stays structural until html render" {
  let project = compile_ok([
    source("index.alt", "See (em (link `about.alt` About))."),
    source("about.alt", "About."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<p>See <em><a href=\"about.html\">About</a></em>.</p>",
  )
}

///|
test "dangling local link is non fatal in normal build" {
  let project = compile_ok([
    source("index.alt", "See (link `missing.alt` Missing)."),
  ])
  @test.assert_eq(project.diagnostics.length(), 1)
  @test.assert_eq(project.dangling_tree_links.length(), 1)
  @test.assert_eq(project.dangling_tree_links[0], {
    source: "index.alt",
    target: "missing.alt",
  })
  @test.assert_eq(
    project.trees[0].html,
    "<p>See <a href=\"#\" data-missing-target=\"missing.alt\">Missing</a>.</p>",
  )
}

///|
test "strict check fails on dangling local link" {
  match
    compile_project_strict(
      @model.Project::new("", [
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
test "embed title renders details summary" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt` Child title)"),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\" open><summary>Child title</summary><p>Child.</p></details>",
  )
}

///|
test "embed options control details and semantic data attrs" {
  let project = compile_ok([
    source(
      "index.alt", "(embed (:numbering true :catalog false :details-open false) `child.alt` Child title)",
    ),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\" data-numbering=\"true\" data-catalog=\"false\"><summary><span class=\"embed-number\">1.</span> Child title</summary><p>Child.</p></details>",
  )
}

///|
test "embed boolean flag option defaults to true" {
  let project = compile_ok([
    source("index.alt", "(embed (:numbering) `child.alt`)"),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<div class=\"embed\" data-tree=\"child\" data-numbering=\"true\"><div class=\"embed-number\">1.</div><p>Child.</p></div>",
  )
}

///|
test "embed target and title support interpolation" {
  let project = compile_ok([
    source(
      "index.alt", "(let target `child.alt`)(let label `Child title`)(embed \"(target)\" \"(label)\")",
    ),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\" open><summary>Child title</summary><p>Child.</p></details>",
  )
}

///|
test "unknown embed option reports diagnostic" {
  match
    compile_project(
      @model.Project::new("", [
        source("index.alt", "(embed (:unknown true) `child.alt`)"),
        source("child.alt", "Child."),
      ]),
    ) {
    Ok(_) => abort("expected unknown embed option")
    Err(error) =>
      @test.assert_eq(error.message, "unknown embed option: unknown")
  }
}

///|
test "missing embed target is hard error" {
  match
    compile_project(
      @model.Project::new("", [source("index.alt", "(embed `missing.alt`)")]),
    ) {
    Ok(_) => abort("expected missing embed target")
    Err(error) =>
      @test.assert_eq(error.message, "missing embed target: missing.alt")
  }
}

///|
test "embed target validation rejects non local target" {
  match
    compile_project(
      @model.Project::new("", [
        source("index.alt", "(embed `https://example.com`)"),
      ]),
    ) {
    Ok(_) => abort("expected invalid embed target")
    Err(error) =>
      @test.assert_eq(
        error.message,
        "(embed ...) target must be a local tree target",
      )
  }
}

///|
test "relative embed target must end with alt extension" {
  match
    compile_project(
      @model.Project::new("", [source("index.alt", "(embed `child`)")]),
    ) {
    Ok(_) => abort("expected invalid relative embed target")
    Err(error) =>
      @test.assert_eq(
        error.message,
        "(embed ...) relative target must end with .alt",
      )
  }
}

///|
test "open embed propagates visible child references to parent footer" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt` Child)"),
    source("child.alt", "Child (link `ref.alt` Ref)."),
    source("ref.alt", "(meta (:asref true :title `Ref title`))Ref."),
  ])
  @test.assert_eq(project.trees[0].references, [slug("ref")])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\" open><summary>Child</summary><p>Child <a href=\"ref.html\">Ref</a>.</p></details><footer class=\"tree-footer\"><section class=\"tree-references\"><h2>References</h2><ol><li><a href=\"ref.html\">Ref title</a></li></ol></section></footer>",
  )
}

///|
test "closed embed does not propagate child references to parent footer" {
  let project = compile_ok([
    source("index.alt", "(embed (:details-open false) `child.alt` Child)"),
    source("child.alt", "Child (link `ref.alt` Ref)."),
    source("ref.alt", "(meta (:asref true :title `Ref title`))Ref."),
  ])
  @test.assert_eq(project.trees[0].references, [])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\"><summary>Child</summary><p>Child <a href=\"ref.html\">Ref</a>.</p></details>",
  )
}

///|
test "untitled embed is visible even when details option is false" {
  let project = compile_ok([
    source("index.alt", "(embed (:details-open false) `child.alt`)"),
    source("child.alt", "Child (link `ref.alt` Ref)."),
    source("ref.alt", "(meta (:asref true :title `Ref title`))Ref."),
  ])
  @test.assert_eq(project.trees[0].references, [slug("ref")])
}

///|
test "open embed propagates child backlinks to parent footer" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt` Child)"),
    source("child.alt", "(meta (:asback true))Child."),
    source("ref.alt", "See (link `child.alt` Child)."),
  ])
  @test.assert_eq(project.trees[0].backlinks, [slug("ref")])
}

///|
test "embed catalog lists embedded descendants" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt` Child)"),
    source("child.alt", "Child. (embed `grand.alt`)"),
    source("grand.alt", "(meta (:title `Grand title`))Grand."),
  ])
  @test.assert_eq(
    project.trees[0].html,
    "<details class=\"embed\" data-tree=\"child\" open><summary>Child</summary><p>Child. </p><div class=\"embed\" data-tree=\"grand\"><p>Grand.</p></div><nav class=\"embed-catalog\" aria-label=\"Embedded content\"><ol><li><a href=\"grand.html\">Grand title</a></li></ol></nav></details>",
  )
}

///|
test "footer mode text and title sorting are applied" {
  let project = compile_ok([
    source(
      "index.alt", "(meta (:footer-mode text :footer-sort-by title))(link `b.alt` B) (link `a.alt` A)",
    ),
    source("a.alt", "(meta (:asref true :title `Alpha`))A."),
    source("b.alt", "(meta (:asref true :title `Beta`))B."),
  ])
  @test.assert_eq(project.trees[0].metadata.footer_mode, "text")
  @test.assert_eq(project.trees[0].metadata.footer_sort_by, Some("title"))
  @test.assert_eq(
    project.trees[0].html,
    "<p><a href=\"b.html\">B</a> <a href=\"a.html\">A</a></p><footer class=\"tree-footer\"><section class=\"tree-references\"><h2>References</h2><ol><li>Alpha</li><li>Beta</li></ol></section></footer>",
  )
}

///|
test "dirty source expansion follows embed and backlink graph" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt`)"),
    source("child.alt", "Child. (embed `grand.alt`) (link `ref.alt` Ref)"),
    source("grand.alt", "Grand."),
    source("ref.alt", "(meta (:asref true))Ref."),
  ])
  @test.assert_eq(@compile.expand_dirty_sources(project, ["child.alt"]), [
    "child.alt", "index.alt", "grand.alt", "ref.alt",
  ])
  @test.assert_eq(@compile.expand_dirty_sources(project, ["ref.alt"]), [
    "ref.alt", "child.alt", "index.alt", "grand.alt",
  ])
}

///|
test "preview project returns html diagnostics and transitive source file dependencies" {
  match
    preview_project(
      @model.Project::new("", [
        source("index.alt", "(embed `child.alt`)"),
        source(
          "child.alt", "(use `lib.sia`)Child (lib.value). (link `missing.alt` Missing)",
        ),
        source("lib.sia", "(let value `ok`)"),
      ]),
      "index.alt",
    ) {
    Err(error) => abort(error.render())
    Ok(preview) => {
      @test.assert_eq(preview.entry_tree_slug, slug("index"))
      @test.assert_eq(preview.diagnostics.length(), 1)
      @test.assert_eq(preview.dangling_tree_links.length(), 1)
      @test.assert_eq(preview.source_file_dependencies, [
        { source: "index.alt", target: "child.alt", kind: @model.TreeEmbed },
        { source: "child.alt", target: "lib.sia", kind: @model.LibraryUse },
      ])
      @test.assert_eq(
        preview.html.contains("<div class=\"embed\" data-tree=\"child\">"),
        true,
      )
    }
  }
}

///|
test "structured preview annotates tree links and embeds" {
  match
    preview_project_structured(
      @model.Project::new("", [
        source("index.alt", "See (link `about.alt` About). (embed `child.alt`)"),
        source("child.alt", "Child (link `about.alt` About)."),
        source("about.alt", "About."),
      ]),
      "index.alt",
    ) {
    Err(error) => abort(error.render())
    Ok(preview) => {
      @test.assert_eq(preview.entry, "index.alt")
      @test.assert_eq(preview.entry_tree_slug, slug("index"))
      @test.assert_eq(preview.tree_links.length(), 2)
      @test.assert_eq(preview.tree_links[0], {
        id: "link-1",
        source: "index.alt",
        target: "about.alt",
        target_source: Some("about.alt"),
        target_slug: Some(slug("about")),
        href: "about.html",
        missing: false,
      })
      @test.assert_eq(preview.tree_links[1], {
        id: "link-2",
        source: "child.alt",
        target: "about.alt",
        target_source: Some("about.alt"),
        target_slug: Some(slug("about")),
        href: "about.html",
        missing: false,
      })
      @test.assert_eq(preview.embeds, [
        {
          id: "embed-1",
          source: "index.alt",
          target: "child.alt",
          target_source: "child.alt",
          target_slug: slug("child"),
          open: true,
        },
      ])
      @test.assert_eq(
        preview.html.contains("data-altsia-link-id=\"link-1\""),
        true,
      )
      @test.assert_eq(
        preview.html.contains("data-altsia-embed-id=\"embed-1\""),
        true,
      )
      @test.assert_eq(preview.assets, [])
    }
  }
}

///|
test "structured preview records dangling tree links" {
  match
    preview_project_structured(
      @model.Project::new("", [
        source("index.alt", "See (link `missing.alt` Missing)."),
      ]),
      "index.alt",
    ) {
    Err(error) => abort(error.render())
    Ok(preview) => {
      @test.assert_eq(preview.diagnostics.length(), 1)
      @test.assert_eq(preview.dangling_tree_links, [
        { source: "index.alt", target: "missing.alt" },
      ])
      @test.assert_eq(preview.tree_links, [
        {
          id: "link-1",
          source: "index.alt",
          target: "missing.alt",
          target_source: None,
          target_slug: None,
          href: "#",
          missing: true,
        },
      ])
      @test.assert_eq(
        preview.html.contains("data-missing-target=\"missing.alt\""),
        true,
      )
    }
  }
}

///|
test "structured preview can omit html annotations" {
  match
    preview_project_structured(
      @model.Project::new("", [
        source("index.alt", "See (link `about.alt` About)."),
        source("about.alt", "About."),
      ]),
      "index.alt",
      preview_options=@model.PreviewOptions::{
        annotate_html: false,
        collect_assets: true,
      },
    ) {
    Err(error) => abort(error.render())
    Ok(preview) => {
      @test.assert_eq(preview.tree_links.length(), 1)
      @test.assert_eq(preview.html.contains("data-altsia-link-id"), false)
      @test.assert_eq(preview.html.contains("href=\"about.html\""), true)
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
      @model.Project::new("", [
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
