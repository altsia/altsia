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
  assert_eq(tokens.map(t => t.typ), [
    "heading", "bullet_list", "blockquote", "fence",
  ])
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
test "MarkdownIt parses yaml front matter after leading blank lines" {
  let source =
    #|
    #|
    #|---
    #|title: Demo
    #|---
    #|# Title
  let tokens = MarkdownIt::parse(source)
  assert_eq(tokens.map(t => t.typ), ["front_matter", "heading"])
  let document = MarkdownIt::parse_document(source)
  assert_eq(document.metadata.map(item => item.key), ["title"])
  assert_eq(document.metadata.map(item => item.value), ["Demo"])
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
  assert_eq(document.metadata.map(item => item.value), [
    "Hello *moon*", "tex $x^2$",
  ])
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
    altsia, "(p Hello (em world) and (strong moon) with (code `x^2`) (a (:href /x) ref).)",
  )
}

///|
test "MarkdownIt parses inline html tags as html_inline tokens" {
  let source = "a <span title=\"1 > 0\">b</span> c"
  let tokens = MarkdownIt::parse(source)
  let children = tokens[0].children
  assert_eq(children.map(t => t.typ), [
    "text", "html_inline", "text", "html_inline", "text",
  ])
  assert_eq(children[1].content, "<span title=\"1 > 0\">")
  assert_eq(children[3].content, "</span>")
}

///|
test "MarkdownIt keeps non-html angle bracket text as plain text" {
  let source = "1 < 2 and <3"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p 1 < 2 and <3)")
}

///|
test "MarkdownIt converts inline html element into structured app" {
  let source = "<span class=\"a\">b</span>"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p (span (:class a) b))")
}

///|
test "MarkdownIt converts markdown with inline html and tex together" {
  let source = "mix <span>$x^2$</span> and <i>$$y^2$$</i> done"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p mix (span k`x^2`) and (i kd`y^2`) done)")
}

///|
test "MarkdownIt parses inline math before dash text" {
  let source = "$x$-y"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p k`x`-y)")
}

///|
test "MarkdownIt parses inline math with markdown special chars inside" {
  let source = "A $f(x)=x^2+t_1x+t_0 \\in k[x], a*b < c$ B"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p A k`f(x)=x^2+t_1x+t_0 \\in k[x], a*b < c` B)")
}

///|
test "MarkdownIt parses block display math fence" {
  let source =
    #|$$
    #|AA
    #|$$
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "kd`AA`")
}

///|
test "MarkdownIt normalize keeps top-level display math with boundary blank lines" {
  let source =
    #|$$
    #|AA
    #|$$
  let altsia = MarkdownIt::to_altsia(source)
  assert_eq(altsia, "\n\nkd`AA`\n\n")
}

///|
test "MarkdownIt parses single-line block display math fence with spaces" {
  let source = "$$ f(x) \\spaces= (x-r)(x+t_1+r) \\spaces\\in F[x] $$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "kd`f(x) \\spaces= (x-r)(x+t_1+r) \\spaces\\in F[x]`")
}

///|
test "MarkdownIt parses single-line block display math fence without spaces" {
  let source = "$$x^2$$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "kd`x^2`")
}

///|
test "MarkdownIt parses block html container with markdown body" {
  let source =
    #|<div class="box">
    #|
    #|mix **b** and $x^2$
    #|
    #|</div>
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(div (:class box) (p mix (strong b) and k`x^2`))")
}

///|
test "MarkdownIt extracts inline tex math from text token" {
  let source = "tex $x^2$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex k`x^2`)")
}

///|
test "MarkdownIt extracts display tex math from text token" {
  let source = "tex $$x^2$$ tail"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex kd`x^2` tail)")
}

///|
test "MarkdownIt keeps brace-nested tex body intact" {
  let source = "tex $\\frac{a}{b}$."
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex k`\\frac{a}{b}`.)")
}

///|
test "MarkdownIt parses math in headings and list items" {
  let source =
    #|# Title $x^2$
    #|
    #|- item $y$
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(h1 Title k`x^2`)
    #|
    #|(ul (li item k`y`))
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
    altsia, "(table (tr (th lhs) (th rhs)) (tr (td k`x^2`) (td kd`y^2`)))",
  )
}

///|
test "MarkdownIt keeps invalid math delimiters as plain text" {
  let source = "a $ x$ b $x $ c $x$2 d $x$ e"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p a $ x$ b $x $ c $x$2 d k`x` e)")
}

///|
test "MarkdownIt ignores escaped dollar opener for math start" {
  let source = "price \\$x$ and $y$"
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p price \\$x$ and k`y`)")
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

///|
test "MarkdownIt converts reference-style links with lambda declarations" {
  let source =
    #|[aczél-engel]: /trees/CN2E.md
    #|
    #|Read [][aczél-engel] and [tree][aczél-engel].
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(λ md_link_ref_1 (content...) (a (:href /trees/CN2E.md) (content)))
    #|
    #|(p Read (md_link_ref_1 aczél-engel) and (md_link_ref_1 tree).)
  assert_eq(altsia, expected)
}

///|
test "MarkdownIt converts footnotes and reference links together" {
  let source =
    #|alpha[^n1].
    #|
    #|[^n1]: beta [x][ref]
    #|[ref]: /r
  let altsia = MarkdownIt::to_altsia(source, normalize=false)
  let expected =
    #|(λ md_link_ref_1 (content...) (a (:href /r) (content)))
    #|
    #|(λ md_footnote_ref_1 () (sup (a (:href #md-footnote-1) 1)))
    #|
    #|(λ md_footnote_item_1 () (li (:id md-footnote-1) beta (md_link_ref_1 x)))
    #|
    #|(p alpha(md_footnote_ref_1).)
    #|
    #|(section (:class footnotes) (ol (md_footnote_item_1)))
  assert_eq(altsia, expected)
}
