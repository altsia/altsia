///|
fn parse_tokens_from_lines(lines : Array[String]) -> Array[MdToken] {
  let tokens : Array[MdToken] = []
  let mut start_line = 0
  let mut link_references : Map[String, MdLinkReference] = Map::new()
  let footnotes : Array[MdFootnote] = []
  match try_consume_front_matter(lines) {
    Some((front_matter, next_line)) => {
      tokens.push(front_matter)
      start_line = next_line
    }
    None => ()
  }
  let (content_lines, extracted_links, extracted_footnote_lines) = md_extract_definitions(
    lines,
    start_line,
  )
  link_references = extracted_links
  for footnote_entry in extracted_footnote_lines {
    let value = footnote_entry.1.join(" ")
    footnotes.push(MdFootnote::{
      label: footnote_entry.0,
      value,
      value_tokens: parse_inline_tokens_with_context(value, link_references, []),
    })
  }
  for token in parse_blocks_from_lines(
    content_lines,
    0,
    link_references,
    footnotes,
  ) {
    tokens.push(token)
  }
  tokens
}

///|
fn parse_document_from_lines(lines : Array[String]) -> MdDocument {
  let mut metadata : Array[MdMetadataItem] = []
  let mut start_line = 0
  let mut link_references : Map[String, MdLinkReference] = Map::new()
  let footnotes : Array[MdFootnote] = []
  match try_consume_front_matter(lines) {
    Some((front_matter, next_line)) => {
      metadata = parse_metadata_from_front_matter_content(front_matter.content)
      start_line = next_line
    }
    None => ()
  }
  let (content_lines, extracted_links, extracted_footnote_lines) = md_extract_definitions(
    lines,
    start_line,
  )
  link_references = extracted_links
  for footnote_entry in extracted_footnote_lines {
    let value = footnote_entry.1.join(" ")
    footnotes.push(MdFootnote::{
      label: footnote_entry.0,
      value,
      value_tokens: parse_inline_tokens_with_context(value, link_references, []),
    })
  }
  MdDocument::{
    metadata,
    tokens: parse_blocks_from_lines(content_lines, 0, link_references, footnotes),
    link_references,
    footnotes,
  }
}

