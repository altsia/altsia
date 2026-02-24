// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn split_markdown_lines(source : String) -> Array[String] {
  let lines = source.split("\n").map(StringView::to_string).collect()
  lines.map(md_strip_trailing_cr)
}

///|
pub fn KoMarkdown::parse_document(source : String) -> MdDocument {
  parse_document_from_lines(split_markdown_lines(source))
}

///|
pub fn KoMarkdown::parse(source : String) -> Array[MdToken] {
  parse_tokens_from_lines(split_markdown_lines(source))
}
