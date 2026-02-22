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
      let html_attrs = attrs.map(x => "\{x.0}=\"\{x.1}\"").join(" ")
      let html_attrs = if attrs.is_empty() {
        html_attrs
      } else {
        " \{html_attrs}"
      }
      let body = children.map(Html::to_string).join("")
      "<\{name}\{html_attrs}>\{body}</\{name}>"
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
        attrs: [],
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
pub fn Html::from(
  doc : Doc,
  f? : (Array[Html]) -> Array[Html] = x => x,
) -> Html {
  Element({
    name: "div",
    attrs: [],
    children: f(doc.map(Html::elaborate_node)),
  })
}

///|
pub fn Html::from_with(
  doc : Doc,
  f? : (Array[Html]) -> Array[Html] = x => x,
  outer : (Array[Html]) -> Html,
) -> Html {
  outer(f(doc.map(Html::elaborate_node)))
}

///|
pub fn Html::visit_text(html : Html, visitor : Visitor[String]) -> Html {
  match html {
    Comment(_) => html
    Text(s) => Text(visitor(s))
    Element({ name, attrs, children }) =>
      Element({
        name,
        attrs,
        children: children.map(h => Html::visit_text(h, visitor)),
      })
  }
}

///|
pub fn Html::visit_element(
  html : Html,
  visitor : Visitor[Element[Html]],
) -> Html {
  match html {
    Comment(_) => html
    Text(s) => Text(s)
    Element({ name, attrs, children }) =>
      Element(
        visitor({
          name,
          attrs,
          children: children.map(h => Html::visit_element(h, visitor)),
        }),
      )
  }
}
