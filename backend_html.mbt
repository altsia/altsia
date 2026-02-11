///|
pub(all) enum Html {
  Text(String)
  Comment(String)
  Element(Element[Html])
} derive(Show)

///|
pub fn Html::to_string(node : Html) -> String {
  match node {
    Comment(s) => "<!-- \{s} -->"
    Text(s) => s
    Element({ name, attrs, children }) => {
      let html_attrs = attrs.to_array().map(x => "\{x.0}=\"\{x.1}\"").join(" ")
      let html_attrs = if attrs.is_empty() {
        html_attrs
      } else {
        " \{html_attrs}"
      }
      let body = children.map(Html::to_string).join("")
      "<\{name}\{html_attrs}>\n\{body}\n</\{name}>"
    }
  }
}

///|
pub fn Html::elaborate_inline(node : InlineNode) -> Html {
  match node {
    Text(s) => Text(s)
    Span({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(Html::elaborate_inline) })
  }
}

///|
pub fn Html::elaborate_block(node : BlockNode) -> Html {
  match node {
    Paragraph(xs) =>
      Element({
        name: "p",
        attrs: @hashmap.HashMap::new(),
        children: xs.map(Html::elaborate_inline),
      })
    Container({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(Html::elaborate_inline) })
  }
}

///|
pub fn Html::elaborate_node(piece : Piece) -> Html {
  match piece {
    Comment(c) => Comment(c)
    Inline(node) => Html::elaborate_inline(node)
    Block(node) => Html::elaborate_block(node)
  }
}

///|
pub fn Html::from(doc : Doc) -> Html {
  Element({
    name: "div",
    attrs: @hashmap.HashMap::new(),
    children: doc.map(Html::elaborate_node),
  })
}

///|
test {
  let source =
    #|
    #|(pre (code))
    #|
    #|```
    #|balabala
    #|```
    #|
    #|
  println(
    source
    |> Stage1::parse
    |> Stage2::pass
    |> Stage3::pass
    |> Html::from
    |> Html::to_string,
  )
}
