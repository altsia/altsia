///|
pub(all) enum Mdx {
  Text(String)
  Comment(String)
  Group(Array[Mdx])
  Element(Element[Mdx])
} derive(Show)

///|
pub fn Mdx::to_string(node : Mdx) -> String {
  match node {
    Comment(s) => "<!-- \{s} -->"
    Text(s) => s
    Group(xs) => xs.map(Mdx::to_string).join("")
    Element({ name, attrs, children }) => {
      let html_attrs = attrs.to_array().map(x => "\{x.0}=\"\{x.1}\"").join(" ")
      let html_attrs = if attrs.is_empty() {
        html_attrs
      } else {
        " \{html_attrs}"
      }
      let body = children.map(Mdx::to_string).join("")
      "<\{name}\{html_attrs}>\n\{body}\n</\{name}>"
    }
  }
}

///|
pub fn Mdx::elaborate_inline(node : InlineNode) -> Mdx {
  match node {
    Text(s) => Text(s)
    Span({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(Mdx::elaborate_inline) })
  }
}

///|
pub fn Mdx::elaborate_block(node : BlockNode) -> Mdx {
  match node {
    Paragraph(xs) => {
      let content = xs.map(Mdx::elaborate_inline)
      content.push(Text("\n\n"))
      Group(content)
    }
    Container({ name, attrs, children }) =>
      Element({ name, attrs, children: children.map(Mdx::elaborate_inline) })
  }
}

///|
pub fn Mdx::elaborate_node(piece : Piece) -> Mdx {
  match piece {
    Comment(c) => Comment(c)
    Inline(node) => Mdx::elaborate_inline(node)
    Block(node) => Mdx::elaborate_block(node)
  }
}

///|
pub fn Mdx::from(doc : Doc) -> Mdx {
  Group(doc.map(Mdx::elaborate_node))
}
