///|
fn attr_scalar(attr : @core.Attr) -> String? {
  match attr.value {
    Some(Scalar(text, _)) => Some(text)
    Some(Bool(value, _)) => Some(value.to_string())
    _ => None
  }
}

///|
fn attr_bool(attr : @core.Attr) -> Bool? {
  match attr.value {
    Some(Bool(value, _)) => Some(value)
    Some(Scalar("true", _)) => Some(true)
    Some(Scalar("false", _)) => Some(false)
    _ => None
  }
}

///|
fn default_metadata(id : String, source_id : String) -> Metadata {
  {
    section_id: id,
    source_id,
    title: None,
    page_title: None,
    taxon: None,
    parent: None,
    show_references: true,
    show_backlinks: true,
    asref: false,
    asback: true,
    footer_mode: "link",
    footer_sort_by: None,
    internal_anon_section: false,
  }
}

///|
fn metadata_from_doc(
  id : String,
  source_id : String,
  doc : @core.Document,
) -> Metadata {
  let mut metadata = default_metadata(id, source_id)
  for node in doc.nodes {
    match node {
      Meta(attrs, _) =>
        for attr in attrs {
          match attr.name {
            "slug" | "section-id" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, section_id: value }
                None => ()
              }
            "title" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, title: Some(value) }
                None => ()
              }
            "page-title" =>
              match attr_scalar(attr) {
                Some(value) =>
                  metadata = { ..metadata, page_title: Some(value) }
                None => ()
              }
            "taxon" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, taxon: Some(value) }
                None => ()
              }
            "parent" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, parent: Some(value) }
                None => ()
              }
            "references" =>
              match attr_bool(attr) {
                Some(value) => metadata = { ..metadata, show_references: value }
                None => ()
              }
            "backlinks" =>
              match attr_bool(attr) {
                Some(value) => metadata = { ..metadata, show_backlinks: value }
                None => ()
              }
            "asref" =>
              match attr_bool(attr) {
                Some(value) => metadata = { ..metadata, asref: value }
                None => ()
              }
            "asback" =>
              match attr_bool(attr) {
                Some(value) => metadata = { ..metadata, asback: value }
                None => ()
              }
            "footer-mode" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, footer_mode: value }
                None => ()
              }
            "footer-sort-by" =>
              match attr_scalar(attr) {
                Some(value) =>
                  metadata = { ..metadata, footer_sort_by: Some(value) }
                None => ()
              }
            "internal-anon-section" =>
              match attr_bool(attr) {
                Some(value) =>
                  metadata = { ..metadata, internal_anon_section: value }
                None => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  metadata
}

///|
fn section_title(section : CompiledSection) -> String {
  match section.metadata.title {
    Some(value) => value
    None =>
      match section.metadata.page_title {
        Some(value) => value
        None => section.id
      }
  }
}
