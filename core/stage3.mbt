///|
pub type Doc = Array[Piece]

///|
pub(all) enum Piece {
  Inline(InlineNode)
  Block(BlockNode)
  Comment(String)
} derive(Eq, Show, Debug)

///|
pub(all) enum InlineNode {
  Text(String)
  Span(Element[InlineNode])
} derive(Eq, Show, Debug)

///|
pub(all) enum BlockNode {
  Paragraph(Array[InlineNode])
  Container(Element[InlineNode])
} derive(Eq, Show, Debug)

///|
pub type Stage3

///|
pub(all) suberror Stage3Error {
  AttributeExpectsAtMostOneValue(values~ : Array[Term], loc~ : SourceLoc?)
  UnexpectedTemplateDefinition(term~ : Term, loc~ : SourceLoc?)
} derive(Eq, Show)
