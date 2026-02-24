// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "KoMarkdown converts reference-style links with local-link rules" {
  let source =
    #|[aczel-engel]: /trees/CN2E.md
    #|
    #|Read [][aczel-engel] and [tree][aczel-engel].
  let local_link_app_name = @kodama.LOCAL_LINK_APP_NAME
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected = "(λ aczel-engel () /trees/CN2E.alt)\n\n(p Read (\{local_link_app_name} /trees/CN2E.alt) and (\{local_link_app_name} (:text tree) /trees/CN2E.alt).)"
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown converts footnotes and reference links together" {
  let source =
    #|alpha[^n1].
    #|
    #|[^n1]: beta [x][ref]
    #|[ref]: /r
  let local_link_app_name = @kodama.LOCAL_LINK_APP_NAME
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected = "(λ ref () /r)\n\n(λ md_footnote_ref_1 () (sup (a (:href #md-footnote-1)1)))\n\n(λ md_footnote_item_1 () (li (:id md-footnote-1)beta (\{local_link_app_name} (:text x) /r)))\n\n(p alpha(md_footnote_ref_1).)\n\n(section (:class footnotes) (ol (md_footnote_item_1)))"
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
