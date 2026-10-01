///|
/// HTML node tree: elements, escaped text, and raw output. Renderers build
/// trees instead of concatenating tag strings; `.render()` escapes text and
/// attribute values and closes elements automatically.
pub(all) enum Node {
  El(String, Array[Attr], Array[Node])
  Text(String)
  Raw(String)
}

///|
pub(all) struct Attr {
  name : String
  value : String?
}

///|
fn el(tag : String, attrs : Array[Attr], children : Array[Node]) -> Node {
  El(tag, attrs, children)
}

///|
fn attr(name : String, value : String) -> Attr {
  { name, value: Some(value), }
}

///|
/// A boolean attribute, rendered without a value (`checked`, `disabled`).
fn attr_flag(name : String) -> Attr {
  { name, value: None, }
}

///|
/// Elements that never have a closing tag.
let void_tags : Array[String] = ["image", "input", "hr", "br", "meta", "link"]

///|
fn Node::render(self : Node) -> String {
  match self {
    Text(s) => escape_html(s)
    Raw(s) => s
    El(tag, attrs, children) => {
      let attr_str = attrs.map(a => a.render()).join("")
      if void_tags.contains(tag) {
        "<\{tag}\{attr_str}>"
      } else {
        "<\{tag}\{attr_str}>\{render_nodes(children)}</\{tag}>"
      }
    }
  }
}

///|
fn render_nodes(nodes : Array[Node]) -> String {
  nodes.map(n => n.render()).join("")
}

///|
fn Attr::render(self : Attr) -> String {
  self.value.map_or(" \{self.name}", v => " \{self.name}=\"\{escape_html(v)}\"")
}

///|
fn escape_html(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
}
