///|
pub type CommonMark

///|
pub fn CommonMark::desugar(html : @core.Html) -> @core.Html {
  html.visit_element(element => {
    let { name, attrs, children } = element
    let name = match name {
      "*" => "em"
      "**" => "strong"
      ">" => "blockquote"
      _ => name
    }
    { name, attrs, children: children.map(h => CommonMark::desugar(h)) }
  })
}
