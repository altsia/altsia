//! Second pass: resolve inline markup and emit events.

// Allowing arbitrary depth nested parentheses inside link destinations
// can create denial of service vulnerabilities. The simplest countermeasure
// is to limit their depth.

///|
const LINK_MAX_NESTED_PARENS : Int = 32

///|
/// Markdown event and source range iterator.
pub struct Parser {
  text : Bytes
  options : Options
  tree : Tree[Item]
  allocs : Allocations
  html_scan_guard : HtmlScanGuard
  // https://github.com/pulldown-cmark/pulldown-cmark/issues/844
  mut link_ref_expansion_limit : Int
  // used by inline passes
  inline_stack : InlineStack
  link_stack : LinkStack
  wikilink_stack : LinkStack
  code_delims : CodeDelims
  math_delims : MathDelims
}

///|
pub fn parse(source : String, options : Options) -> Array[Event] {
  let text = @utf8.encode(source)
  let parser = new_parser(text, options)
  let events : Array[Event] = []
  while true {
    guard parser.next_event() is Some(event) else { break }
    events.push(event)
  }
  events
}

///|
/// Creates a new event parser for a markdown string with given options.
pub fn new_parser(text : Bytes, options : Options) -> Parser {
  let (tree, allocs) = run_first_pass(text, options)
  tree.reset()
  Parser::{
    text,
    options,
    tree,
    allocs,
    html_scan_guard: html_scan_guard_default(),
    // always allow 100KiB
    link_ref_expansion_limit: text.length().max(100_000),
    inline_stack: inline_stack_new(),
    link_stack: link_stack_new(),
    wikilink_stack: link_stack_new(),
    code_delims: code_delims_new(),
    math_delims: math_delims_new(),
  }
}

///|
/// Returns the next event, or `None` when the document is exhausted.
pub fn Parser::next_event(self : Parser) -> Event? {
  self.next_event_range().map(ev => ev.0)
}

///|
/// Returns the next event and its source range (start, end), or `None`.
pub fn Parser::next_event_range(self : Parser) -> (Event, Int, Int)? {
  guard self.tree.cur() is Some(cur_ix) else { return self.pop_event() }
  let cur_ix = if self.tree.nodes[cur_ix].item.body is TightParagraph {
    // tight paragraphs emit nothing
    ignore(self.tree.push())
    self.tree.cur().unwrap()
  } else {
    cur_ix
  }
  if item_body_is_maybe_inline(self.tree.nodes[cur_ix].item.body) {
    self.handle_inline()
  }

  let node = self.tree.nodes[cur_ix]
  let item = node.item
  let event = item_to_event(item, self.text, self.allocs)
  match event {
    Start(_) => ignore(self.tree.push())
    _ => ignore(self.tree.next_sibling(cur_ix))
  }
  Some((event, item.start, item.end))
}

///|
/// Emits the `End` event of the node being popped, or `None` when the
/// document is exhausted.
fn Parser::pop_event(self : Parser) -> (Event, Int, Int)? {
  guard self.tree.pop() is Some(ix) else { return None }
  guard !(self.tree.nodes[ix].item.body is TightParagraph) else {
    // tight paragraphs emit nothing
    ignore(self.tree.next_sibling(ix))
    return self.next_event_range()
  }
  let tag_end = body_to_tag_end(self.tree.nodes[ix].item.body)
  ignore(self.tree.next_sibling(ix))
  let span = (self.tree.nodes[ix].item.start, self.tree.nodes[ix].item.end)
  Some((End(tag_end), span.0, span.1))
}

///|
fn body_to_tag_end(body : ItemBody) -> TagEnd {
  match body {
    Paragraph => TagEnd::Paragraph
    Emphasis => TagEnd::Emphasis
    Superscript => TagEnd::Superscript
    Subscript => TagEnd::Subscript
    Strong => TagEnd::Strong
    Strikethrough => TagEnd::Strikethrough
    Highlight => TagEnd::Highlight
    Link(_) => TagEnd::Link
    Image(_) => TagEnd::Image
    Heading(level, _) => TagEnd::Heading(level)
    IndentCodeBlock | FencedCodeBlock(_) => TagEnd::CodeBlock
    Container(_, kind, _) => TagEnd::ContainerBlock(kind)
    BlockQuote(kind) => TagEnd::BlockQuote(kind)
    HtmlBlock => TagEnd::HtmlBlock
    List(_, c, _) => TagEnd::List(c == b'.' || c == b')')
    ListItem(_) => TagEnd::Item
    TableHead => TagEnd::TableHead
    TableCell => TagEnd::TableCell
    TableRow => TagEnd::TableRow
    Table(_) => TagEnd::Table
    FootnoteDefinition(_) => TagEnd::FootnoteDefinition
    MetadataBlock(kind) => TagEnd::MetadataBlock(kind)
    DefinitionList(_) => TagEnd::DefinitionList
    DefinitionListTitle => TagEnd::DefinitionListTitle
    DefinitionListDefinition(_) => TagEnd::DefinitionListDefinition
    _ => abort("unexpected item body")
  }
}

///|
fn item_to_event(item : Item, text : Bytes, allocs : Allocations) -> Event {
  let tag = match item.body {
    Text(_) =>
      return Text(
        @utf8.decode_lossy(text.exact_view(start=item.start, end=item.end)),
      )
    Code(cow_ix) => return Code(allocs.take_cow(cow_ix))
    SynthesizeText(cow_ix) => return Text(allocs.take_cow(cow_ix))
    SynthesizeChar(c) => return Text(c.to_string())
    HtmlBlock => Tag::HtmlBlock
    Html =>
      return Html(
        replace_nuls(
          @utf8.decode_lossy(text.exact_view(start=item.start, end=item.end)),
        ),
      )
    InlineHtml =>
      return InlineHtml(
        replace_nuls(
          @utf8.decode_lossy(text.exact_view(start=item.start, end=item.end)),
        ),
      )
    OwnedInlineHtml(cow_ix) => return InlineHtml(allocs.take_cow(cow_ix))
    SoftBreak => return SoftBreak
    HardBreak(_) => return HardBreak
    FootnoteReference(cow_ix) =>
      return FootnoteReference(allocs.take_cow(cow_ix))
    TaskListMarker(checked) => return TaskListMarker(checked)
    Rule => return Rule
    Paragraph => Tag::Paragraph
    Emphasis => Tag::Emphasis
    Superscript => Tag::Superscript
    Subscript => Tag::Subscript
    Strong => Tag::Strong
    Strikethrough => Tag::Strikethrough
    Highlight => Tag::Highlight
    Link(link_ix) => {
      let (link_type, dest_url, title, id) = allocs.take_link(link_ix)
      Tag::Link(link_type~, dest_url~, title~, id~)
    }
    Image(link_ix) => {
      let (link_type, dest_url, title, id) = allocs.take_link(link_ix)
      Tag::Image(link_type~, dest_url~, title~, id~)
    }
    Heading(level, Some(heading_ix)) => {
      let attrs = allocs.heading_at(heading_ix)
      Tag::Heading(
        level~,
        id=attrs.id,
        classes=attrs.classes,
        attrs=attrs.attrs,
      )
    }
    Heading(level, None) => Tag::Heading(level~, id=None, classes=[], attrs=[])
    FencedCodeBlock(cow_ix) => Tag::CodeBlock(Fenced(allocs.take_cow(cow_ix)))
    IndentCodeBlock => Tag::CodeBlock(Indented)
    Container(_, kind, cow_ix) =>
      Tag::ContainerBlock(kind, allocs.take_cow(cow_ix))
    BlockQuote(kind) => Tag::BlockQuote(kind)
    List(_, c, listitem_start) =>
      if c == b'.' || c == b')' {
        Tag::List(Some(listitem_start))
      } else {
        Tag::List(None)
      }
    ListItem(_) => Tag::Item
    TableHead => Tag::TableHead
    TableCell => Tag::TableCell
    TableRow => Tag::TableRow
    Table(alignment_ix) => Tag::Table(allocs.take_alignment(alignment_ix))
    FootnoteDefinition(cow_ix) =>
      Tag::FootnoteDefinition(allocs.take_cow(cow_ix))
    MetadataBlock(kind) => Tag::MetadataBlock(kind)
    Math(cow_ix, is_display) => {
      let s = allocs.take_cow(cow_ix)
      return if is_display { DisplayMath(s) } else { InlineMath(s) }
    }
    DefinitionList(_) => Tag::DefinitionList
    DefinitionListTitle => Tag::DefinitionListTitle
    DefinitionListDefinition(_) => Tag::DefinitionListDefinition
    _ => abort("unexpected item body")
  }
  Start(tag)
}
