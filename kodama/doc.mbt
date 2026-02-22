///|
pub(all) struct IndexedDocument {
  doc_id : String
  slug : String
  title : @core.Term
  metadata : RawMetadata
} derive(Eq, Show, Debug)

///|
pub fn parse_terms_for_forester(source : String) -> Array[@core.Term] raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
}

///|
fn doc_id_to_slug(doc_id : String) -> String {
  let mut slash_index = -1
  let mut dot_index = -1
  for i in 0..<doc_id.length() {
    let ch = doc_id.get_char(i).unwrap()
    if ch == '/' || ch == '\\' {
      slash_index = i
      dot_index = -1
      continue
    }
    if ch == '.' {
      dot_index = i
    }
  }
  if dot_index > slash_index {
    doc_id.unsafe_substring(start=0, end=dot_index)
  } else {
    doc_id
  }
}

///|
pub fn IndexedDocument::title_with_slug(doc : IndexedDocument) -> String {
  "\{doc.title_text()} [\{doc.slug}]"
}

///|
pub fn IndexedDocument::title_text(doc : IndexedDocument) -> String {
  for text in doc.metadata.get_plain_text(KEY_PAGE_TITLE).iter() {
    return text
  }
  let plain = term_plain_text(doc.title)
  if plain.is_empty() {
    doc.title.to_string()
  } else {
    plain
  }
}

///|
fn default_title_term(text : String) -> @core.Term {
  @core.Term::Text(text, { start_offset: 0, end_offset: 0, line: 1, column: 1 })
}

///|
fn title_from_named_arg(
  metadata : RawMetadata,
  fallback : @core.Term,
) -> @core.Term {
  metadata.title_term(fallback)
}

///|
pub fn forester_index_document(
  doc_id : String,
  source : String,
) -> IndexedDocument raise {
  let terms = parse_terms_for_forester(source)
  let metadata = extract_raw_metadata_from_terms(terms)
  // Slug is auto-detected from doc id and does not accept user override.
  let slug = doc_id_to_slug(doc_id)
  let title_fallback = default_title_term(slug)
  let title = title_from_named_arg(metadata, title_fallback)
  IndexedDocument::{ doc_id, slug, title, metadata }
}
