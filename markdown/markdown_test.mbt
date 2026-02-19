///|
test "MarkdownIt parses markdown with rule-chain tokens" {
  let source =
    #|# Title
    #|
    #|- one
    #|- two
    #|
    #|> quote
    #|
    #|```js
    #|let x = 1
    #|```
  let tokens = MarkdownIt::parse(source)
  assert_eq(tokens.map(t => t.typ), ["heading", "bullet_list", "blockquote", "fence"])
  assert_eq(tokens[0].tag, "h1")
  assert_eq(tokens[1].children.map(t => t.typ), ["list_item", "list_item"])
  assert_eq(tokens[3].attrs, [("info", "js")])
}

///|
test "MarkdownIt parses yaml front matter at document start" {
  let source =
    #|---
    #|title: Demo
    #|tags:
    #|  - altsia
    #|---
    #|# Title
  let tokens = MarkdownIt::parse(source)
  assert_eq(tokens.map(t => t.typ), ["front_matter", "heading"])
  assert_eq(tokens[0].content, "title: Demo\ntags:\n  - altsia")
  assert_eq(tokens[1].tag, "h1")
}

///|
test "MarkdownIt parses structured metadata from front matter" {
  let source =
    #|---
    #|title: Hello *moon*
    #|equation: tex $x^2$
    #|invalid-line
    #|---
    #|# Title
  let document = MarkdownIt::parse_document(source)
  assert_eq(document.tokens.map(t => t.typ), ["heading"])
  assert_eq(document.metadata.map(item => item.key), ["title", "equation"])
  assert_eq(document.metadata.map(item => item.value), ["Hello *moon*", "tex $x^2$"])
  assert_eq(document.metadata[0].value_tokens.map(t => t.typ), ["text", "em"])
}

///|
test "MarkdownIt converts front matter into structured metadata node" {
  let source =
    #|---
    #|title: Demo
    #|author: You
    #|---
    #|
    #|# Title
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(% metadata (:title Demo) (:author You))
    #|
    #|(h1 Title)
  assert_eq(altsia, expected)
}

///|
test "MarkdownIt ignores non-leading front matter fence" {
  let source =
    #|paragraph
    #|---
    #|title: Demo
    #|---
  let tokens = MarkdownIt::parse(source)
  assert_eq(tokens.map(t => t.typ), ["paragraph"])
}

///|
test "MarkdownIt keeps unclosed front matter as normal paragraph" {
  let source =
    #|---
    #|title: Demo
    #|# Title
  let tokens = MarkdownIt::parse(source)
  assert_eq(tokens.map(t => t.typ), ["paragraph", "heading"])
  assert_true(!tokens.map(t => t.typ).contains("front_matter"))
}

///|
test "MarkdownIt converts inline markdown to altsia apps" {
  let source = "Hello *world* and **moon** with `x^2` [ref](/x)."
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(
    altsia,
    "(p Hello (em world) and (strong moon) with (code `x^2`) (a (:href /x) ref).)",
  )
}

///|
test "MarkdownIt extracts inline tex math from text token" {
  let source = "tex $x^2$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex (k `x^2`))")
}

///|
test "MarkdownIt extracts display tex math from text token" {
  let source = "tex $$x^2$$ tail"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex (kd `x^2`) tail)")
}

///|
test "MarkdownIt keeps brace-nested tex body intact" {
  let source = "tex $\\frac{a}{b}$."
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex (k `\\frac{a}{b}`).)")
}

///|
test "MarkdownIt parses math in headings and list items" {
  let source =
    #|# Title $x^2$
    #|
    #|- item $y$
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(h1 Title (k `x^2`))
    #|
    #|(ul (li item (k `y`)))
  assert_eq(altsia, expected)
}

///|
test "MarkdownIt parses table cells and math inside them" {
  let source =
    #|| lhs | rhs |
    #|| --- | --- |
    #|| $x^2$ | $$y^2$$ |
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(
    altsia,
    "(table (tr (th lhs) (th rhs)) (tr (td (k `x^2`)) (td (kd `y^2`))))",
  )
}

///|
test "MarkdownIt keeps invalid math delimiters as plain text" {
  let source = "a $ x$ b $x $ c $x$2 d $x$ e"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p a $ x$ b $x $ c $x$2 d (k `x`) e)")
}

///|
test "MarkdownIt ignores escaped dollar opener for math start" {
  let source = "price \\$x$ and $y$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p price \\$x$ and (k `y`))")
}

///|
test "MarkdownIt converts ordered list and fenced code block" {
  let source =
    #|1. first
    #|2. second
    #|
    #|```js
    #|a(b)
    #|```
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(ol (:start 1) (li first) (li second))
    #|
    #|(pre (code (:class language-js) a\(b\)))
  assert_eq(altsia, expected)
}

///|
test "MarkdownIt exposes normalized shape output" {
  let source = "# H1"
  let shapes = MarkdownIt::to_shapes(source)
  assert_eq(shapes, [App([Text("h1"), Text("H1")], [Space])])
}

///|
test "MarkdownIt generated altsia stays stage1-parseable after normalize" {
  let source =
    #|# Title
    #|
    #|aa *bb*.
  let altsia = MarkdownIt::to_altsia(source, max_width=80)
  let _ = @core.Stage1::parse(altsia)
}
