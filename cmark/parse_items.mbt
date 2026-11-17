///|
#warnings("-unused_field")
//! Core data structures for the parser: items and allocations.
// `span` and `use_count` are carried over even though this port omits the
// HTML renderer / broken-link callback that consumes them.

/// Index types into `Allocations` arrays.

struct Item {
  /// A tree node item; spans a byte range of the source.
  mut start : Int32
  mut end : Int32
  mut body : ItemBody
}

///|
impl Default for Item with fn default() -> Item {
  { start: 0, end: 0, body: Root, }
}

///|
/// The body of a tree node.
priv enum ItemBody {
  // These are possible inline items, need to be resolved in second pass.

  // repeats, can_open, can_close
  MaybeEmphasis(Int32, Bool, Bool)
  // brace context
  MaybeMath(Int32)
  // quote byte, can_open, can_close
  MaybeSmartQuote(Byte, Bool, Bool)
  MaybeCode(Int32, Bool) // number of backticks, preceded by backslash
  MaybeHtml
  MaybeLinkOpen
  // bool indicates whether or not the preceding section could be a reference
  MaybeLinkClose(Bool)
  MaybeImage

  // These are inline items after resolution.
  Emphasis
  Strong
  Strikethrough
  Highlight
  Superscript
  Subscript
  Math(Int32, Bool) // true for display math
  Code(Int32)
  Link(Int32)
  Image(Int32)
  FootnoteReference(Int32)
  TaskListMarker(Bool)

  // These are also inline items.
  InlineHtml
  OwnedInlineHtml(Int32)
  SynthesizeText(Int32)
  SynthesizeChar(Char)
  Html
  Text(Bool) // backslash_escaped
  SoftBreak
  // true = is backlash
  HardBreak(Bool)

  // Dummy node at the top of the tree - should not be used otherwise!
  Root

  // These are block items.
  Paragraph
  TightParagraph
  Rule
  Heading(HeadingLevel, Int32?) // heading level
  FencedCodeBlock(Int32)
  HtmlBlock
  BlockQuote(BlockQuoteKind?)
  Container(Int32, ContainerKind, Int32) // (fence length, kind, descriptor)
  List(Bool, Byte, Int64) // is_tight, list character, list start index
  ListItem(Int32) // indent level
  FootnoteDefinition(Int32)
  MetadataBlock(MetadataBlockKind)

  // Definition lists
  DefinitionList(Bool) // is_tight
  MaybeDefinitionListTitle
  DefinitionListTitle
  DefinitionListDefinition(Int32)

  // Tables
  Table(Int32)
  TableHead
  TableRow
  TableCell
}

///|
fn item_body_is_maybe_inline(body : ItemBody) -> Bool {
  match body {
    MaybeEmphasis(_, _, _)
    | MaybeMath(_)
    | MaybeSmartQuote(_, _, _)
    | MaybeCode(_, _)
    | MaybeHtml
    | MaybeLinkOpen
    | MaybeLinkClose(_)
    | MaybeImage => true
    _ => false
  }
}

///|
fn item_body_is_inline(body : ItemBody) -> Bool {
  match body {
    MaybeEmphasis(_, _, _)
    | MaybeMath(_)
    | MaybeSmartQuote(_, _, _)
    | MaybeCode(_, _)
    | MaybeHtml
    | MaybeLinkOpen
    | MaybeLinkClose(_)
    | MaybeImage
    | Emphasis
    | Strong
    | Strikethrough
    | Highlight
    | Math(_, _)
    | Code(_)
    | Link(_)
    | Image(_)
    | FootnoteReference(_)
    | TaskListMarker(_)
    | InlineHtml
    | OwnedInlineHtml(_)
    | SynthesizeText(_)
    | SynthesizeChar(_)
    | Html
    | Text(_)
    | SoftBreak
    | HardBreak(_) => true
    _ => false
  }
}

///|
/// Contains the destination URL, title and source span of a reference definition.
priv struct LinkDef {
  dest : String
  title : String?
  _span : (Int32, Int32)
}

///|
/// Contains the destination URL, title and source span of a footnote definition.
priv struct FootnoteDef {
  mut _use_count : Int32
}

///|
/// Used by the heading attributes extension.
priv struct HeadingAttributes {
  id : String?
  classes : Array[String]
  attrs : Array[(String, String?)]
}

///|
/// Allocations of owned strings, links, alignments and headings.
struct Allocations {
  refdefs : Map[String, LinkDef]
  footdefs : Map[String, FootnoteDef]
  links : Array[(LinkType, String, String, String)]
  cows : Array[String]
  alignments : Array[Array[Alignment]]
  headings : Array[HeadingAttributes]
}

///|
fn allocations_new() -> Allocations {
  {
    refdefs: Map([], capacity=0),
    footdefs: Map([], capacity=0),
    links: [],
    cows: [],
    alignments: [],
    headings: [],
  }
}

///|
fn Allocations::allocate_cow(self : Allocations, cow : String) -> Int32 {
  let ix = self.cows.length()
  self.cows.push(cow)
  ix
}

///|
fn Allocations::allocate_link(
  self : Allocations,
  ty : LinkType,
  url : String,
  title : String,
  id : String,
) -> Int32 {
  let ix = self.links.length()
  self.links.push((ty, url, title, id))
  ix
}

///|
fn Allocations::allocate_alignment(
  self : Allocations,
  alignment : Array[Alignment],
) -> Int32 {
  let ix = self.alignments.length()
  self.alignments.push(alignment)
  ix
}

///|
fn Allocations::allocate_heading(
  self : Allocations,
  attrs : HeadingAttributes,
) -> Int32 {
  let ix = self.headings.length()
  self.headings.push(attrs)
  ix + 1
}

///|
fn Allocations::take_cow(self : Allocations, ix : Int32) -> String {
  let v = self.cows[ix]
  self.cows[ix] = ""
  v
}

///|
fn Allocations::take_link(
  self : Allocations,
  ix : Int32,
) -> (LinkType, String, String, String) {
  let v = self.links[ix]
  self.links[ix] = (ShortcutUnknown, "", "", "")
  v
}

///|
fn Allocations::take_alignment(
  self : Allocations,
  ix : Int32,
) -> Array[Alignment] {
  let v = self.alignments[ix]
  self.alignments[ix] = []
  v
}

///|
fn Allocations::heading_at(self : Allocations, ix : Int32) -> HeadingAttributes {
  self.headings[ix - 1]
}
