///|
test "KoMarkdown converts front matter into structured metadata node" {
  let source =
    #|---
    #|title: Demo
    #|author: You
    #|---
    #|
    #|# Title
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(metadata (:title Demo) (:author You))
    #|
    #|(h1 Title)
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown converts inline markdown to altsia apps" {
  let source = "Hello *world* and **moon** with `x^2` [local link](/x)."
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(
    altsia, "(p Hello (em world) and (strong moon) with (code `x^2`) (ref (:text local link) /x).)",
  )
}

///|
test "KoMarkdown rewrites local markdown link suffix to .alt" {
  let source = "[doc](docs/intro.md)"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p (ref (:text doc) docs/intro.alt))")
}

///|
test "KoMarkdown keeps external href as plain text in link app" {
  let source = "[site](https://example.com)"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p (a (:href https://example.com) site))")
}

///|
test "KoMarkdown keeps non-html angle bracket text as plain text" {
  let source = "1 < 2 and <3"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p 1 < 2 and <3)")
}

///|
test "KoMarkdown converts inline html element into structured app" {
  let source = "<span class=\"a\">b</span>"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p (span (:class a) b))")
}

///|
test "KoMarkdown converts ordered list and fenced code block" {
  let source =
    #|1. first
    #|2. second
    #|
    #|```js
    #|a(b)
    #|```
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(ol (:start 1) (li first) (li second))
    #|
    #|(pre (code (:class language-js) a\(b\)))
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown exposes normalized shape output" {
  let source = "# H1"
  let shapes = KoMarkdown::to_shapes(source)
  assert_eq(shapes, [App([Text("h1"), Text("H1")], [Space])])
}

///|
test "KoMarkdown generated altsia stays stage1-parseable after normalize" {
  let source =
    #|# Title
    #|
    #|aa *bb*.
  let altsia = KoMarkdown::to_altsia(source, max_width=80)
  let _ = @core.Stage1::parse(altsia)
}
