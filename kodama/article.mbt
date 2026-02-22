///|
pub fn outer_article(children : Array[@core.Html]) -> @core.Html {
  @core.Html::Element({
    name: "article",
    attrs: Map::new(),
    children: [
      @core.Html::Element({ name: "section", attrs: Map::new(), children: [] }),
    ],
  })
}
