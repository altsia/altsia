///|
test "graph content captures callbacks instead of final html" {
  let doc = parse_doc(
    "index.alt", "Before (link `about.alt` About) and (embed `child.alt`).",
  )
  let content = match compile_graph_content(doc) {
    Ok(content) => content
    Err(error) => abort(error.render())
  }
  let callbacks : Array[GraphCallback] = []
  let html_chunks : Array[String] = []
  for chunk in content {
    match chunk {
      CallbackContent(callback) => callbacks.push(callback)
      HtmlContent(html) => html_chunks.push(html)
    }
  }
  @test.assert_eq(html_chunks.join("").contains("<a href"), false)
  @test.assert_eq(callbacks.length(), 2)
  match callbacks[0] {
    LinkCallback(link) => {
      @test.assert_eq(link.target, "about.alt")
      @test.assert_eq(link.text, Some("About"))
    }
    _ => abort("expected link callback")
  }
  match callbacks[1] {
    EmbedCallback(embed) => {
      @test.assert_eq(embed.target, "child.alt")
      @test.assert_eq(embed.title, None)
      @test.assert_eq(embed.option, EmbedOption::default())
    }
    _ => abort("expected embed callback")
  }
}
