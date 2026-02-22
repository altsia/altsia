///|
pub fn term_metadata(
  items : Array[@core.Term],
  loc : @core.SourceLoc,
) -> @core.Term {
  let li_terms = items.map(item => {
    hel("li", loc, attrs=[hclass(["meta-item"], loc)], children=[item])
  })
  hel(
    "div",
    loc,
    attrs=[hclass(["metadata"], loc)],
    children=[hel("ul", loc, children=li_terms)],
  )
}

///|
fn taxon_term(taxon : Taxon, loc : @core.SourceLoc) -> @core.Term {
  hel(
    "span",
    loc,
    attrs=[hclass(["taxon"], loc)],
    children=[htext(taxon.display(), loc)],
  )
}

///|
pub fn term_section_summary(
  taxon : Taxon?,
  title : @core.Term,
  metadata_items : Array[@core.Term],
  loc : @core.SourceLoc,
) -> @core.Term {
  let h1_children : Array[@core.Term] = []
  for taxon in taxon.iter() {
    h1_children.push(taxon_term(taxon, loc))
  }
  h1_children.push(title)

  let header_children : Array[@core.Term] = [hel("h1", loc, children=h1_children)]
  if !metadata_items.is_empty() {
    header_children.push(term_metadata(metadata_items, loc))
  }

  // slug, edit actions
  hel(
    "summary",
    loc,
    children=[hel("header", loc, children=header_children)],
  )
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
