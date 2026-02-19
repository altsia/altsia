///|
pub(all) enum Gap {
  Tight
  Space
} derive(Eq, Show, Debug)

///|
pub(all) enum NormalizedShape {
  Text(String)
  QuoteInline(String)
  App(Array[NormalizedShape], Array[Gap])
} derive(Eq, Show, Debug)

///|
pub(all) struct MdToken {
  typ : String
  tag : String
  content : String
  attrs : Array[(String, String)]
  children : Array[MdToken]
} derive(Eq, Show, Debug)

///|
pub(all) struct MdMetadataItem {
  key : String
  value : String
  value_tokens : Array[MdToken]
} derive(Eq, Show, Debug)

///|
pub(all) struct MdDocument {
  metadata : Array[MdMetadataItem]
  tokens : Array[MdToken]
} derive(Eq, Show, Debug)

///|
pub(all) struct BlockState {
  lines : Array[String]
  tokens : Array[MdToken]
}

///|
pub(all) struct InlineState {
  source : String
  tokens : Array[MdToken]
}

///|
pub type MarkdownIt
