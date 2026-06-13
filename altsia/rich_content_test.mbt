///|
test "rich content captures directives instead of final html" {
  let doc = parse_doc(
    "index.alt", "Before (link `about.alt` About) and (embed `child.alt`).",
  )
  let content = match @content.compile_rich_content(doc) {
    Ok(content) => content
    Err(error) => abort(error.render())
  }
  let directives : Array[@model.RichContentDirective] = []
  let text_chunks : Array[String] = []
  for node in content.nodes {
    match node {
      @model.RichDirective(directive) => directives.push(directive)
      @model.RichText(text, _) => text_chunks.push(text)
      @model.RichElement(_, _, _, _) => ()
    }
  }
  @test.assert_eq(text_chunks.join("").contains("<a href"), false)
  @test.assert_eq(directives.length(), 2)
  match directives[0] {
    @model.RichLinkDirective(link) => {
      @test.assert_eq(link.target, "about.alt")
      @test.assert_eq(link.text, Some("About"))
    }
    _ => abort("expected link directive")
  }
  match directives[1] {
    @model.RichEmbedDirective(embed) => {
      @test.assert_eq(embed.target, "child.alt")
      @test.assert_eq(embed.title, None)
      @test.assert_eq(embed.option, @model.EmbedOption::default())
    }
    _ => abort("expected embed directive")
  }
}
