///|
test "KoMarkdown converts reference-style links with lambda declarations" {
  let source =
    #|[acz茅l-engel]: /trees/CN2E.md
    #|
    #|Read [][acz茅l-engel] and [tree][acz茅l-engel].
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(λ acz茅l-engel () /trees/CN2E.md)
    #|
    #|(p Read (a (:href (acz茅l-engel))) and (a (:href (acz茅l-engel)) tree).)
  assert_eq(altsia, expected)
  let html = altsia
    |> @core.Stage1::parse
    |> @core.Stage2::pass
    |> @core.Stage2Etale::expand_program
    |> @core.Stage3::pass
    |> @core.Html::from
    |> @core.Html::to_string
  assert_true(html.contains("<a href=\"/trees/CN2E.md\"></a>"))
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
    #|(λ md_footnote_item_1 () (li (:id md-footnote-1)beta (a (:href (ref)) x)))
    #|
    #|(p alpha(md_footnote_ref_1).)
    #|
    #|(section (:class footnotes) (ol (md_footnote_item_1)))
  assert_eq(altsia, expected)
}
