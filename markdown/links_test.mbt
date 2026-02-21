///|
test "KoMarkdown converts reference-style links with local-link rules" {
  let source =
    #|[aczel-engel]: /trees/CN2E.md
    #|
    #|Read [][aczel-engel] and [tree][aczel-engel].
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(λ aczel-engel () /trees/CN2E.alt)
    #|
    #|(p Read (ref /trees/CN2E.alt) and (ref (:text tree) /trees/CN2E.alt).)
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown converts footnotes and reference links together" {
  let source =
    #|alpha[^n1].
    #|
    #|[^n1]: beta [x][ref]
    #|[ref]: /r
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(λ ref () /r)
    #|
    #|(λ md_footnote_ref_1 () (sup (a (:href #md-footnote-1)1)))
    #|
    #|(λ md_footnote_item_1 () (li (:id md-footnote-1)beta (ref (:text x) /r)))
    #|
    #|(p alpha(md_footnote_ref_1).)
    #|
    #|(section (:class footnotes) (ol (md_footnote_item_1)))
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown keeps non-local reference links as lambda href values" {
  let source =
    #|[site]: https://example.com
    #|
    #|Visit [site][site].
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(λ site () https://example.com)
    #|
    #|(p Visit (a (:href (site)) site).)
  assert_eq(altsia, expected)
}
