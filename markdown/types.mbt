// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

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
pub(all) struct MdLinkReference {
  label : String
  href : String
} derive(Eq, Show, Debug)

///|
pub(all) struct MdFootnote {
  label : String
  value : String
  value_tokens : Array[MdToken]
} derive(Eq, Show, Debug)

///|
pub(all) struct MdDocument {
  metadata : Array[MdMetadataItem]
  tokens : Array[MdToken]
  link_references : Map[String, MdLinkReference]
  footnotes : Array[MdFootnote]
} derive(Eq, Show, Debug)

///|
pub(all) struct BlockState {
  lines : Array[String]
  tokens : Array[MdToken]
  link_references : Map[String, MdLinkReference]
  footnotes : Array[MdFootnote]
}

///|
pub(all) struct InlineState {
  source : String
  tokens : Array[MdToken]
  link_references : Map[String, MdLinkReference]
  footnotes : Array[MdFootnote]
}

///|
pub type KoMarkdown
