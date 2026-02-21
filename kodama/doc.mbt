///|
pub(all) struct IndexedDocument {
  doc_id : String
  slug : String
  title : String
  metadata : DocMetadata
} derive(Eq, Show, Debug)

///|
pub fn parse_terms_for_forester(source : String) -> Array[@core.Term] raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
}

///|
fn term_values_to_text(values : Array[@core.Term]) -> String {
  let mut out = ""
  for value in values {
    match value {
      @core.Term::Text(text, _) => out = out + text
      _ => ()
    }
  }
  out
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
  "\{doc.title} [\{doc.slug}]"
}

///|
pub fn forester_index_document(
  doc_id : String,
  source : String,
) -> IndexedDocument raise {
  let terms = parse_terms_for_forester(source)
  let metadata = extract_doc_metadata_from_terms(terms)
  let slug = match metadata.get("slug") {
    Some(value) => term_values_to_text(value.values)
    None => doc_id_to_slug(doc_id)
  }
  let title = match metadata.get("title") {
    Some(value) => term_values_to_text(value.values)
    None => slug
  }
  IndexedDocument::{ doc_id, slug, title, metadata }
}
