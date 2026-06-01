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
fn default_metadata(slug : TreeSlug, source_id : String) -> Metadata {
  {
    slug,
    source_id,
    lang: None,
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
  }
}

///|
fn metadata_from_doc(
  slug : TreeSlug,
  source_id : String,
  doc : @core.Document,
  allow_slug_override? : Bool = true,
) -> Metadata {
  let mut metadata = default_metadata(slug, source_id)
  metadata = apply_metadata_attrs(metadata, doc.nodes, allow_slug_override~)
  metadata
}

///|
fn metadata_from_tree(
  slug : TreeSlug,
  source_id : String,
  attrs : Array[@core.Attr],
  doc : @core.Document,
) -> Metadata {
  let mut metadata = default_metadata(slug, source_id)
  metadata = apply_tree_attrs(metadata, attrs)
  metadata = apply_metadata_attrs(
    metadata,
    doc.nodes,
    allow_slug_override=false,
  )
  metadata
}

///|
fn apply_tree_attrs(metadata : Metadata, attrs : Array[@core.Attr]) -> Metadata {
  let mut result = metadata
  for attr in attrs {
    match attr.name {
      "lang" =>
        match attr_scalar(attr) {
          Some(value) => result = { ..result, lang: Some(value) }
          None => ()
        }
      "title" =>
        match attr_scalar(attr) {
          Some(value) => result = { ..result, title: Some(value) }
          None => ()
        }
      "page-title" =>
        match attr_scalar(attr) {
          Some(value) => result = { ..result, page_title: Some(value) }
          None => ()
        }
      "taxon" =>
        match attr_scalar(attr) {
          Some(value) =>
            result = { ..result, taxon: Some(taxon_from_attrs(value, attrs)) }
          None => ()
        }
      "parent" =>
        match attr_scalar(attr) {
          Some(value) =>
            result = { ..result, parent: Some(TreeSlug::parse(value)) }
          None => ()
        }
      _ => ()
    }
  }
  result
}

///|
fn apply_metadata_attrs(
  metadata : Metadata,
  nodes : Array[@core.Node],
  allow_slug_override~ : Bool,
) -> Metadata {
  let mut metadata = metadata
  for node in nodes {
    match node {
      Meta(attrs, _) =>
        for attr in attrs {
          match attr.name {
            "slug" =>
              if allow_slug_override {
                match attr_scalar(attr) {
                  Some(value) =>
                    metadata = { ..metadata, slug: TreeSlug::parse(value) }
                  None => ()
                }
              }
            "lang" =>
              match attr_scalar(attr) {
                Some(value) => metadata = { ..metadata, lang: Some(value) }
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
                Some(value) =>
                  metadata = {
                    ..metadata,
                    taxon: Some(taxon_from_attrs(value, attrs)),
                  }
                None => ()
              }
            "taxon-display" =>
              match attr_scalar(attr) {
                Some(value) =>
                  match metadata.taxon {
                    Some(taxon) =>
                      metadata = {
                        ..metadata,
                        taxon: Some({ ..taxon, display: Some(value) }),
                      }
                    None => ()
                  }
                None => ()
              }
            "parent" =>
              match attr_scalar(attr) {
                Some(value) =>
                  metadata = {
                    ..metadata,
                    parent: Some(TreeSlug::parse(value)),
                  }
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
            _ => ()
          }
        }
      _ => ()
    }
  }
  metadata
}

///|
fn taxon_from_attrs(key : String, attrs : Array[@core.Attr]) -> Taxon {
  let mut display : String? = None
  for attr in attrs {
    if attr.name == "taxon-display" {
      match attr_scalar(attr) {
        Some(value) => display = Some(value)
        None => ()
      }
    }
  }
  Taxon::new(key, display?)
}

///|
fn tree_title(tree : CompiledTree) -> String {
  match tree.metadata.title {
    Some(value) => value
    None =>
      match tree.metadata.page_title {
        Some(value) => value
        None => tree.slug.canonical()
      }
  }
}
