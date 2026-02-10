///|
pub(all) enum Html {
  Text(String)
  Comment(String)
  Element(HtmlElement)
}

///|
pub struct HtmlElement {
  name : String
  attrs : @hashmap.HashMap[String, String]
  children : Array[Html]
}

///|
pub fn elaborate_inline(node : InlineNode) -> Html {
  match node {
    Text(s) => Text(s)
    Span({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(elaborate_inline) })
  }
}

///|
pub fn elaborate_block(node : BlockNode) -> Html {
  match node {
    Paragraph(xs) =>
      Element({
        name: "p",
        attrs: @hashmap.HashMap::new(),
        children: xs.map(elaborate_inline),
      })
    Container({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(elaborate_inline) })
  }
}

///|
pub fn Html::elaborate_node(piece : Piece) -> Html {
  match piece {
    Comment(c) => Comment(c)
    Inline(node) => elaborate_inline(node)
    Block(node) => elaborate_block(node)
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
