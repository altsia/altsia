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
