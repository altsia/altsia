///|
/// Code block kind.
pub(all) enum CodeBlockKind {
  Indented
  /// The `String` describes the language of the code, which may be empty.
  Fenced(String)
} derive(Debug)

///|
pub extend CodeBlockKind with Debug::{to_repr}

///|
pub fn CodeBlockKind::is_indented(self : CodeBlockKind) -> Bool {
  self is Indented
}

///|
pub fn CodeBlockKind::is_fenced(self : CodeBlockKind) -> Bool {
  self is Fenced(_)
}

///|
/// Block quote kind (Note, Tip, Important, Warning, Caution).
pub(all) enum BlockQuoteKind {
  Note
  Tip
  Important
  Warning
  Caution
} derive(Debug)

///|
pub extend BlockQuoteKind with Debug::{to_repr}

///|
/// Container block kind (Spoiler only).
pub(all) enum ContainerKind {
  Default
  Spoiler
} derive(Debug)

///|
pub extend ContainerKind with Debug::{to_repr}

///|
/// Metadata block kind.
pub(all) enum MetadataBlockKind {
  YamlStyle
  PlusesStyle
} derive(Debug)

///|
pub extend MetadataBlockKind with Debug::{to_repr}

///|
/// Tags for elements that can contain other elements.
pub(all) enum Tag {
  /// A paragraph of text and other inline elements.
  Paragraph
  /// A heading, with optional identifier, classes and custom attributes.
  Heading(
    level~ : HeadingLevel,
    id~ : String?,
    classes~ : Array[String],
    /// The first item of the tuple is the attr and second one the value.
    attrs~ : Array[(String, String?)]
  )
  /// A block quote.
  BlockQuote(BlockQuoteKind?)
  /// A code block.
  CodeBlock(CodeBlockKind)
  /// A container block with the given kind and descriptor.
  ContainerBlock(ContainerKind, String)
  /// An HTML block.
  HtmlBlock
  /// A list. If the list is ordered the field indicates the number of the
  /// first item. Contains only list items.
  List(Int64?)
  /// A list item.
  Item
  /// A footnote definition. The value contained is the footnote's label.
  FootnoteDefinition(String)
  DefinitionList
  DefinitionListTitle
  DefinitionListDefinition
  /// A table. Contains a vector describing the text-alignment for each of its
  /// columns.
  Table(Array[Alignment])
  TableHead
  TableRow
  TableCell

  // span-level tags
  Emphasis
  Strong
  Strikethrough
  Highlight
  Superscript
  Subscript
  /// A link.
  Link(
    link_type~ : LinkType,
    dest_url~ : String,
    title~ : String,
    /// Identifier of reference links, e.g. `world` in the link `[hello][world]`.
    id~ : String
  )
  /// An image.
  Image(
    link_type~ : LinkType,
    dest_url~ : String,
    title~ : String,
    /// Identifier of reference links, e.g. `world` in the link `[hello][world]`.
    id~ : String
  )
  /// A metadata block.
  MetadataBlock(MetadataBlockKind)
} derive(Debug)

///|
pub extend Tag with Debug::{to_repr}

///|
/// The end of a `Tag`.
pub(all) enum TagEnd {
  Paragraph
  Heading(HeadingLevel)
  BlockQuote(BlockQuoteKind?)
  CodeBlock
  ContainerBlock(ContainerKind)
  HtmlBlock
  /// A list, `true` for ordered lists.
  List(Bool)
  Item
  FootnoteDefinition
  DefinitionList
  DefinitionListTitle
  DefinitionListDefinition
  Table
  TableHead
  TableRow
  TableCell
  Emphasis
  Strong
  Strikethrough
  Highlight
  Superscript
  Subscript
  Link
  Image
  MetadataBlock(MetadataBlockKind)
} derive(Debug)

///|
pub extend TagEnd with Debug::{to_repr}

///|
/// Heading levels.
pub(all) enum HeadingLevel {
  H1
  H2
  H3
  H4
  H5
  H6
} derive(Debug)

///|
pub extend HeadingLevel with Debug::{to_repr}

///|
fn HeadingLevel::to_int(self : HeadingLevel) -> Int {
  match self {
    H1 => 1
    H2 => 2
    H3 => 3
    H4 => 4
    H5 => 5
    H6 => 6
  }
}

///|
fn int_to_heading_level(v : Int) -> HeadingLevel? {
  match v {
    1 => Some(H1)
    2 => Some(H2)
    3 => Some(H3)
    4 => Some(H4)
    5 => Some(H5)
    6 => Some(H6)
    _ => None
  }
}

/// Type specifier for links.
// The *Unknown link types only arise through a broken-link callback, which
// this port does not implement. They remain in the public `LinkType` enum for
// API fidelity.

///|
#warnings("-unused_constructor")
pub(all) enum LinkType {
  /// Inline link like `[foo](bar)`
  Inline
  /// Reference link like `[foo][bar]`
  Reference
  /// Reference without destination in the document, resolved by a callback
  ReferenceUnknown
  /// Collapsed link like `[foo][]`
  Collapsed
  /// Collapsed link without destination in the document
  CollapsedUnknown
  /// Shortcut link like `[foo]`
  Shortcut
  /// Shortcut without destination in the document
  ShortcutUnknown
  /// Autolink like `<http://foo.bar/baz>`
  Autolink
  /// Email address in autolink like `<john@example.org>`
  Email
  /// Wikilink link like `[[foo]]` or `[[foo|bar]]`
  WikiLink(Bool)
} derive(Debug)

///|
pub extend LinkType with Debug::{to_repr}

///|
/// Markdown events generated in a preorder traversal of the document tree.
pub(all) enum Event {
  /// Start of a tagged element.
  Start(Tag)
  /// End of a tagged element.
  End(TagEnd)
  /// A text node.
  Text(String)
  /// An inline code node.
  Code(String)
  /// An inline math environment node.
  InlineMath(String)
  /// A display math environment node.
  DisplayMath(String)
  /// An HTML node.
  Html(String)
  /// An inline HTML node.
  InlineHtml(String)
  /// A reference to a footnote with the given label.
  FootnoteReference(String)
  /// A soft line break.
  SoftBreak
  /// A hard line break.
  HardBreak
  /// A horizontal ruler.
  Rule
  /// A task list marker, `true` when checked.
  TaskListMarker(Bool)
} derive(Debug)

///|
pub extend Event with Debug::{to_repr}

///|
/// Table column text alignment.
pub(all) enum Alignment {
  None
  Left
  Center
  Right
} derive(Debug)

///|
pub extend Alignment with Debug::{to_repr}
