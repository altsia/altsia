///|
pub fn term_metadata(items : Array[HtmlTermNode]) -> HtmlTermNode {
  let items = items.map(item => {
    hel("li", attrs=[("class", "meta-item")], children=[item])
  })
  hel("div", attrs=[("class", "metadata")], children=[hel("ul", children=items)])
}

///|
pub fn term_section_summary(
  taxon : Taxon?,
  title : HtmlTermNode,
  metadata_items : Array[HtmlTermNode],
) -> HtmlTermNode {
  let html_taxon = taxon.map_or([], taxon => {
    [hel("span", attrs=[("class", "taxon")], children=[htext(taxon.display())])]
  })

  let html_metadata = ite(
    metadata_items.is_empty(),
    () => [], // 
    () => [term_metadata(metadata_items)],
  )

  // slug, 
  // edit, 
  hel("summary", children=[
    hel(
      "header",
      children=[hel("h1", children=[..html_taxon, title]), ..html_metadata],
    ),
  ])
}

///|
pub fn outer_section(content : Array[@core.Html]) -> @core.Html {
  @core.Html::Element({
    name: "section",
    attrs: [("class", "block")],
    children: [
      @core.Html::Element({
        name: "details",
        attrs: [("open", "")],
        children: content,
      }),
    ],
  })
}

///|
pub fn outer_article(content : Array[@core.Html]) -> @core.Html {
  @core.Html::Element({
    name: "article",
    attrs: [],
    children: [outer_section(content)],
  })
}
