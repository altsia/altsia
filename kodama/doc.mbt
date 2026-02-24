// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
pub(all) struct IndexedDocument {
  id : DocumentId
  title : @core.Term
  metadata : RawMetadata
} derive(Eq, Show, Debug)

///|
pub type DocumentId = String

///|
pub fn parse_terms_for_forester(source : String) -> Array[@core.Term] raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
}

///|
pub fn IndexedDocument::title_with_slug(doc : IndexedDocument) -> String {
  "\{doc.title_text()} [\{doc.slug()}]"
}

///|
/// Slug is auto-detected from doc id and does not accept user override.
pub fn IndexedDocument::slug(doc : IndexedDocument) -> String {
  path_to_slug(@path.Path::new(doc.id))
}

///|
pub fn IndexedDocument::title_text(doc : IndexedDocument) -> String {
  doc.metadata
  .get_plain_text(KEY_PAGE_TITLE)
  .unwrap_or_else(() => {
    match term_plain_text(doc.title) {
      plain if plain.is_empty() => doc.title.to_string()
      plain => plain
    }
  })
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
  id : String,
  source : String,
) -> IndexedDocument raise {
  let terms = parse_terms_for_forester(source)
  let metadata = extract_raw_metadata_from_terms(terms)
  let title_fallback = default_title_term("unresolved")
  let title = title_from_named_arg(metadata, title_fallback)
  IndexedDocument::{ id, title, metadata }
}
