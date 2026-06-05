///|
test "rich content captures directives instead of final html" {
  let doc = parse_doc(
    "index.alt", "Before (link `about.alt` About) and (embed `child.alt`).",
  )
  let content = match compile_rich_content(doc) {
    Ok(content) => content
    Err(error) => abort(error.render())
  }
  let directives : Array[RichContentDirective] = []
  let html_chunks : Array[String] = []
  for chunk in content {
    match chunk {
      DirectiveChunk(directive) => directives.push(directive)
      HtmlChunk(html) => html_chunks.push(html)
    }
  }
  @test.assert_eq(html_chunks.join("").contains("<a href"), false)
  @test.assert_eq(directives.length(), 2)
  match directives[0] {
    RichLinkDirective(link) => {
      @test.assert_eq(link.target, "about.alt")
      @test.assert_eq(link.text, Some("About"))
    }
    _ => abort("expected link directive")
  }
  match directives[1] {
    RichEmbedDirective(embed) => {
      @test.assert_eq(embed.target, "child.alt")
      @test.assert_eq(embed.title, None)
      @test.assert_eq(embed.option, EmbedOption::default())
    }
    _ => abort("expected embed directive")
  }
}
