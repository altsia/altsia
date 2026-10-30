///|
/// Content prepared for rendering. Paragraphs and inline runs are produced by
/// `organize`; the parser's tree remains unchanged.
pub(all) enum Node {
  Text(String)
  Strong(Array[Node])
  Emph(Array[Node])
  Code(String)
  SoftBreak
  HardBreak
  InlineMath(String)
  FootnoteRef(String)
  Comment(String)
  Paragraph(Array[Node])
  InlineRun(Array[Node])
  Heading(Int32, Array[Node], Map[String, Value])
  UnorderedList(Array[ListItem])
  OrderedList(Array[ListItem])
  FencedCode(String?, String)
  DisplayMath(String)
  ThematicBreak
  Table(TableRow, Array[TableRow], Array[@parsing.TableAlignment])
  FootnoteDef(String, Array[Node])
  Element(Element)
} derive(Eq, Debug)

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with Debug::{to_repr}

///|
pub(all) struct TableRow {
  cells : Array[Array[Node]]
} derive(Eq, Debug)

///|
pub extend TableRow with Eq::{equal, not_equal}

///|
pub extend TableRow with Debug::{to_repr}

///|
pub(all) struct ListItem {
  checked : Bool?
  content : Array[Node]
  children : Array[Node]
} derive(Eq, Debug)

///|
pub extend ListItem with Eq::{equal, not_equal}

///|
pub extend ListItem with Debug::{to_repr}

///|
/// Argument values with content and nested calls already organized.
pub(all) enum Value {
  Text(String)
  Integer(Int32)
  Content(Array[Node])
  Call(Array[Node])
  Comment(String)
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with Debug::{to_repr}

///|
pub(all) struct Element {
  tag : String
  /// Content arguments are consumed into `content`; other arguments stay here.
  positional : Array[Value]
  named : Map[String, Value]
  /// Positional content arguments, concatenated before paragraph organization.
  content : Array[Node]
} derive(Eq, Debug)

///|
pub extend Element with Eq::{equal, not_equal}

///|
pub extend Element with Debug::{to_repr}

///|
/// Only fully inline content participates in an enclosing paragraph. In
/// particular, emphasis around a structural element retains that structure.
pub fn Node::is_inline(self : Node) -> Bool {
  match self {
    Text(_)
    | Code(_)
    | SoftBreak
    | HardBreak
    | InlineMath(_)
    | FootnoteRef(_)
    | Comment(_) => true
    InlineRun(nodes) | Strong(nodes) | Emph(nodes) => nodes.all(Node::is_inline)
    Element(element) =>
      element.tag != "quote" &&
      element.tag != "pagebreak" &&
      element.content.all(Node::is_inline)
    _ => false
  }
}
