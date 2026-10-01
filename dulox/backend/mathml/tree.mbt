///|
/// A private MathML tree centralizes XML escaping and preserves attribute order.
priv enum MathMlNode {
  Element(String, Array[(String, String)], Array[MathMlNode])
  Text(String)
}

///|
fn element(
  name : String,
  children? : Array[MathMlNode] = [],
  attributes? : Array[(String, String)] = [],
) -> MathMlNode {
  Element(name, attributes, children)
}

///|
fn text_node(value : String) -> MathMlNode {
  Text(value)
}

///|
fn MathMlNode::with_attribute(
  self : MathMlNode,
  key : String,
  value : String,
) -> MathMlNode {
  match self {
    Element(name, attributes, children) =>
      Element(name, attributes + [(key, value)], children)
    Text(_) => self
  }
}

///|
fn MathMlNode::to_markup(self : MathMlNode) -> String {
  match self {
    Text(value) => escape_xml(value)
    Element(name, attributes, children) => {
      let rendered_attributes = attributes
        .map(pair => {
          let (key, value) = pair
          " \{key}=\"\{escape_xml(value)}\""
        })
        .join("")
      let rendered_children = children.map(child => child.to_markup()).join("")
      "<\{name}\{rendered_attributes}>\{rendered_children}</\{name}>"
    }
  }
}

///|
fn MathMlNode::text_content(self : MathMlNode) -> String {
  match self {
    Text(value) => value
    Element(_, _, children) =>
      children.map(child => child.text_content()).join("")
  }
}

///|
fn escape_xml(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#x27;")
}

///|
fn make_row(nodes : Array[MathMlNode]) -> MathMlNode {
  match nodes {
    [node] => node
    _ => element("mrow", children=nodes)
  }
}

///|
fn MathMlNode::is_empty(node : MathMlNode) -> Bool {
  match node {
    Text(value) => value.length() == 0
    Element(_, _, children) =>
      children.length() == 0 || children.all(MathMlNode::is_empty)
  }
}

///|
fn combine_expression(nodes : Array[MathMlNode]) -> Array[MathMlNode] {
  let result : Array[MathMlNode] = []
  for node in nodes {
    guard result.length() > 0 else {
      result.push(node)
      continue
    }
    let previous = result[result.length() - 1]
    match (previous, node) {
      (
        Element("mn", left_attrs, left_children),
        Element("mn", right_attrs, right_children),
      ) if left_attrs == right_attrs =>
        result[result.length() - 1] = Element(
          "mn",
          left_attrs,
          left_children + right_children,
        )
      (
        Element("mtext", left_attrs, left_children),
        Element("mtext", right_attrs, right_children),
      ) if left_attrs == right_attrs =>
        result[result.length() - 1] = Element(
          "mtext",
          left_attrs,
          left_children + right_children,
        )
      // \not: overlay the combining long solidus (U+0338) onto the following
      // symbol, mirroring KaTeX buildMathML.
      (
        Element("mi", _, [Text("\u0338")]),
        Element(kind, right_attrs, [Text(right_text), .. rest]),
      ) if (kind == "mi" || kind == "mo" || kind == "mn") &&
        right_text.length() > 0 =>
        result[result.length() - 1] = Element(
          kind,
          right_attrs,
          [Text(overlay_not(right_text))] + Array::from_iter(rest.iter()),
        )
      _ => result.push(node)
    }
  }
  result
}

///|
fn overlay_not(text : String) -> String {
  "\{text.unsafe_substring(start=0, end=1)}\u0338\{text.unsafe_substring(start=1, end=text.length())}"
}
