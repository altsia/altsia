///|
test "filename language suffix does not set tree language" {
  let project = compile_ok([source("doc.zh-CN.alt", "(meta (:taxon theorem))")])
  let tree = project.trees[0]
  @test.assert_eq(tree.slug, slug("doc.zh-CN"))
  @test.assert_eq(tree.metadata.lang, None)
  match tree.metadata.taxon {
    Some(taxon) => {
      @test.assert_eq(taxon.data_key(), "theorem")
      @test.assert_eq(taxon.display(tree.metadata.lang), "Theorem. ")
    }
    None => abort("expected taxon")
  }
}

///|
test "title is rich content with plain text fallback" {
  let project = compile_ok([
    source(
      "doc.alt", "(let heading (_ (em Important)))(meta (:title (heading)))Body.",
    ),
  ])
  match project.trees[0].metadata.title {
    Some((content, fallback_text)) => {
      @test.assert_eq(fallback_text, "Important")
      @test.assert_eq(content.length(), 1)
      match content[0] {
        HtmlChunk(html) => @test.assert_eq(html, "<em>Important</em>")
        DirectiveChunk(_) => abort("expected title html")
      }
    }
    None => abort("expected rich title")
  }
}

///|
test "preview title derives from rich title unless page title overrides it" {
  match
    preview_project(
      Project::new("", [
        source(
          "doc.alt", "(let heading (_ (em Important)))(meta (:title (heading)))Body.",
        ),
      ]),
      "doc.alt",
    ) {
    Ok(preview) => @test.assert_eq(preview.title, Some("Important"))
    Err(error) => abort(error.render())
  }
  match
    preview_project(
      Project::new("", [
        source(
          "doc.alt", "(let heading (_ (em Important)))(meta (:title (heading) :page-title `Plain title`))Body.",
        ),
      ]),
      "doc.alt",
    ) {
    Ok(preview) => @test.assert_eq(preview.title, Some("Plain title"))
    Err(error) => abort(error.render())
  }
}

///|
test "taxon display follows explicit language metadata" {
  let project = compile_ok([
    source("doc.alt", "(meta (:lang zh-CN :taxon theorem))"),
  ])
  match project.trees[0].metadata.taxon {
    Some(taxon) =>
      @test.assert_eq(taxon.display(project.trees[0].metadata.lang), "定理")
    None => abort("expected taxon")
  }
}

///|
test "taxon display override is plain and does not change key" {
  let project = compile_ok([
    source(
      "doc.alt", "(tree (:slug child :lang zh-CN :taxon theorem :taxon-display `主要定理`) Body.)",
    ),
  ])
  match project.trees[1].metadata.taxon {
    Some(taxon) => {
      @test.assert_eq(taxon.data_key(), "theorem")
      @test.assert_eq(
        taxon.display(project.trees[1].metadata.lang),
        "主要定理",
      )
    }
    None => abort("expected taxon")
  }
}
