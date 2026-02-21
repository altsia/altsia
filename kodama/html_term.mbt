///|
/// Lightweight HTML-like node model for building `@core.Term` trees.
pub(all) enum HtmlTermNode {
  Text(String)
  Element(HtmlTermElement)
} derive(Eq, Show, Debug)

///|
pub(all) struct HtmlTermElement {
  tag : String
  attrs : Array[(String, String)]
  children : Array[HtmlTermNode]
} derive(Eq, Show, Debug)

///|
fn html_attr_to_term(
  attr : (String, String),
  loc : @core.SourceLoc,
) -> @core.Term {
  let (name, value) = attr
  @core.Term::App(
    normalize_named_arg_key(name),
    [@core.Term::Text(value, loc)],
    loc,
  )
}

///|
fn html_element_to_term(
  element : HtmlTermElement,
  loc : @core.SourceLoc,
) -> @core.Term {
  let args : Array[@core.Term] = []
  for attr in element.attrs {
    args.push(html_attr_to_term(attr, loc))
  }
  for child in element.children {
    args.push(child.to_term(loc))
  }
  @core.Term::App(element.tag, args, loc)
}

///|
/// Build `@core.Term` from a lightweight HTML node.
#alias(hterm)
pub fn HtmlTermNode::to_term(
  node : HtmlTermNode,
  loc : @core.SourceLoc,
) -> @core.Term {
  match node {
    Text(content) => @core.Term::Text(content, loc)
    Element(element) => html_element_to_term(element, loc)
  }
}

///|
#alias(htext)
pub fn html_text_node(content : String) -> HtmlTermNode {
  HtmlTermNode::Text(content)
}

///|
#alias(hel)
pub fn html_element_node(
  tag : String,
  attrs? : Array[(String, String)] = [],
  children? : Array[HtmlTermNode] = [],
) -> HtmlTermNode {
  HtmlTermNode::Element(HtmlTermElement::{ tag, attrs, children })
}

///|
#alias(hattr)
pub fn html_attr(name : String, value : String) -> (String, String) {
  (name, value)
}

///|
#alias(hclass)
pub fn html_class_attr(classes : Array[String]) -> (String, String) {
  let names = classes.filter(name => !name.is_empty())
  ("class", names.join(" "))
}
