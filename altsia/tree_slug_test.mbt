///|
test "extracts explicit tree as independent output with sibling slug" {
  let project = compile_ok([
    source("math/a.alt", "Root. (tree (:slug b :title `B`) Child.)"),
  ])
  @test.assert_eq(project.trees.length(), 2)
  @test.assert_eq(project.trees[0].slug, slug("math/a"))
  @test.assert_eq(
    project.trees[0].html,
    "<p>Root. </p><details class=\"embed\" data-tree=\"math/b\" open><summary>B</summary><p>Child.</p></details>",
  )
  @test.assert_eq(project.trees[1].slug, slug("math/b"))
  @test.assert_eq(project.trees[1].html, "<p>Child.</p>")
  @test.assert_eq(project.trees[1].parent, Some(slug("math/a")))
}

///|
test "anonymous tree renders as hash anchor without independent output" {
  let project = compile_ok([source("math/a.alt", "Root. (tree Anonymous.)")])
  @test.assert_eq(project.trees.length(), 1)
  @test.assert_eq(
    project.trees[0].html,
    "<p>Root. </p><section id=\"math/a-1\">Anonymous.</section>",
  )
}

///|
test "relative alt target resolves to file slug" {
  let project = compile_ok([
    source("math/a.alt", "A."),
    source("math/c.alt", "(link `a.alt` A) and (link `/math/a` Absolute)."),
  ])
  @test.assert_eq(
    project.trees[1].html,
    "<p><a href=\"math/a.html\">A</a> and <a href=\"math/a.html\">Absolute</a>.</p>",
  )
}
