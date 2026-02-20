///|
pub type MarkdownAbbrev

///|
pub fn MarkdownAbbrev::desugar(html : Html) -> Html {
  html.visit_element(element => {
    let { name, attrs, children } = element
    let name = match name {
      "*" => "em"
      "**" => "strong"
      ">" => "blockquote"
      _ => name
    }
    { name, attrs, children: children.map(h => MarkdownAbbrev::desugar(h)) }
  })
}
