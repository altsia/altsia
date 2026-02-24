// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "KoMarkdown parses markdown with rule-chain tokens" {
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
  let tokens = KoMarkdown::parse(source)
  assert_eq(tokens.map(t => t.typ), [
    "heading", "bullet_list", "blockquote", "fence",
  ])
  assert_eq(tokens[0].tag, "h1")
  assert_eq(tokens[1].children.map(t => t.typ), ["list_item", "list_item"])
  assert_eq(tokens[3].attrs, [("info", "js")])
}

///|
test "KoMarkdown parses yaml front matter at document start" {
  let source =
    #|---
    #|title: Demo
    #|tags:
    #|  - altsia
    #|---
    #|# Title
  let tokens = KoMarkdown::parse(source)
  assert_eq(tokens.map(t => t.typ), ["front_matter", "heading"])
  assert_eq(tokens[0].content, "title: Demo\ntags:\n  - altsia")
  assert_eq(tokens[1].tag, "h1")
}

///|
test "KoMarkdown parses yaml front matter after leading blank lines" {
  let source =
    #|
    #|
    #|---
    #|title: Demo
    #|---
    #|# Title
  let tokens = KoMarkdown::parse(source)
  assert_eq(tokens.map(t => t.typ), ["front_matter", "heading"])
  let document = KoMarkdown::parse_document(source)
  assert_eq(document.metadata.map(item => item.key), ["title"])
  assert_eq(document.metadata.map(item => item.value), ["Demo"])
}

///|
test "KoMarkdown parses structured metadata from front matter" {
  let source =
    #|---
    #|title: Hello *moon*
    #|equation: tex $x^2$
    #|invalid-line
    #|---
    #|# Title
  let document = KoMarkdown::parse_document(source)
  assert_eq(document.tokens.map(t => t.typ), ["heading"])
  assert_eq(document.metadata.map(item => item.key), ["title", "equation"])
  assert_eq(document.metadata.map(item => item.value), [
    "Hello *moon*", "tex $x^2$",
  ])
  assert_eq(document.metadata[0].value_tokens.map(t => t.typ), ["text", "em"])
}

///|
test "KoMarkdown ignores non-leading front matter fence" {
  let source =
    #|paragraph
    #|---
    #|title: Demo
    #|---
  let tokens = KoMarkdown::parse(source)
  assert_eq(tokens.map(t => t.typ), ["paragraph"])
}

///|
test "KoMarkdown keeps unclosed front matter as normal paragraph" {
  let source =
    #|---
    #|title: Demo
    #|# Title
  let tokens = KoMarkdown::parse(source)
  assert_eq(tokens.map(t => t.typ), ["paragraph", "heading"])
  assert_true(!tokens.map(t => t.typ).contains("front_matter"))
}

///|
test "KoMarkdown parses inline html tags as html_inline tokens" {
  let source = "a <span title=\"1 > 0\">b</span> c"
  let tokens = KoMarkdown::parse(source)
  let children = tokens[0].children
  assert_eq(children.map(t => t.typ), [
    "text", "html_inline", "text", "html_inline", "text",
  ])
  assert_eq(children[1].content, "<span title=\"1 > 0\">")
  assert_eq(children[3].content, "</span>")
}
