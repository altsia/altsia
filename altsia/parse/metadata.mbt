///|
fn default_metadata(
  slug : @model.TreeSlug,
  source_id : String,
) -> @model.Metadata {
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
  slug : @model.TreeSlug,
  source_id : String,
  doc : @core.Document,
  env : @core.CompileEnv,
  allow_slug_override? : Bool = true,
) -> @model.Metadata raise @core.Diagnostic {
  let mut metadata = default_metadata(slug, source_id)
  metadata = apply_metadata_attrs(
    metadata,
    doc.nodes,
    env,
    allow_slug_override~,
  )
  metadata
}

///|
fn metadata_from_tree(
  slug : @model.TreeSlug,
  source_id : String,
  attrs : Array[@core.Attr],
  doc : @core.Document,
  env : @core.CompileEnv,
) -> @model.Metadata raise @core.Diagnostic {
  let mut metadata = default_metadata(slug, source_id)
  metadata = apply_tree_attrs(metadata, attrs, env)
  metadata = apply_metadata_attrs(
    metadata,
    doc.nodes,
    env,
    allow_slug_override=false,
  )
  metadata
}

///|
fn apply_tree_attrs(
  metadata : @model.Metadata,
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> @model.Metadata raise @core.Diagnostic {
  let mut result = metadata
  for attr in attrs {
    match attr.name {
      "lang" => {
        let value = optional_attr_scalar(attr, env)
        if value is Some(value) {
          result = { ..result, lang: Some(value) }
        }
      }
      "title" => {
        let title = rich_text_from_attr(attr, env)
        if title is Some(value) {
          result = { ..result, title: Some(value) }
        }
      }
      "page-title" => {
        let value = optional_attr_scalar(attr, env)
        if value is Some(value) {
          result = { ..result, page_title: Some(value) }
        }
      }
      "taxon" => {
        let value = optional_attr_scalar(attr, env)
        if value is Some(value) {
          let taxon = taxon_from_attrs(value, attrs, env)
          result = { ..result, taxon: Some(taxon) }
        }
      }
      "parent" => {
        let value = optional_attr_scalar(attr, env)
        if value is Some(value) {
          result = { ..result, parent: Some(@model.TreeSlug::parse(value)) }
        }
      }
      _ => ()
    }
  }
  result
}

///|
fn apply_metadata_attrs(
  metadata : @model.Metadata,
  nodes : Array[@core.Node],
  env : @core.CompileEnv,
  allow_slug_override~ : Bool,
) -> @model.Metadata raise @core.Diagnostic {
  let mut metadata = metadata
  for node in nodes {
    match node {
      Doc(attrs, _) =>
        for attr in attrs {
          match attr.name {
            "slug" =>
              if allow_slug_override {
                let value = optional_attr_scalar(attr, env)
                if value is Some(value) {
                  metadata = { ..metadata, slug: @model.TreeSlug::parse(value) }
                }
              }
            "lang" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                metadata = { ..metadata, lang: Some(value) }
              }
            }
            "title" => {
              let title = rich_text_from_attr(attr, env)
              if title is Some(value) {
                metadata = { ..metadata, title: Some(value) }
              }
            }
            "page-title" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                metadata = { ..metadata, page_title: Some(value) }
              }
            }
            "taxon" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                let taxon = taxon_from_attrs(value, attrs, env)
                metadata = { ..metadata, taxon: Some(taxon) }
              }
            }
            "taxon-display" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                if metadata.taxon is Some(taxon) {
                  metadata = {
                    ..metadata,
                    taxon: Some(taxon.with_display(value)),
                  }
                }
              }
            }
            "parent" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                metadata = {
                  ..metadata,
                  parent: Some(@model.TreeSlug::parse(value)),
                }
              }
            }
            "references" => {
              let value = optional_attr_bool(
                attr,
                "metadata option requires a boolean value: " + attr.name,
              )
              if value is Some(value) {
                metadata = { ..metadata, show_references: value }
              }
            }
            "backlinks" => {
              let value = optional_attr_bool(
                attr,
                "metadata option requires a boolean value: " + attr.name,
              )
              if value is Some(value) {
                metadata = { ..metadata, show_backlinks: value }
              }
            }
            "asref" => {
              let value = optional_attr_bool(
                attr,
                "metadata option requires a boolean value: " + attr.name,
              )
              if value is Some(value) {
                metadata = { ..metadata, asref: value }
              }
            }
            "asback" => {
              let value = optional_attr_bool(
                attr,
                "metadata option requires a boolean value: " + attr.name,
              )
              if value is Some(value) {
                metadata = { ..metadata, asback: value }
              }
            }
            "footer-mode" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                metadata = { ..metadata, footer_mode: value }
              }
            }
            "footer-sort-by" => {
              let value = optional_attr_scalar(attr, env)
              if value is Some(value) {
                metadata = { ..metadata, footer_sort_by: Some(value) }
              }
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
fn optional_attr_scalar(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> String? raise @core.Diagnostic {
  match attr.value {
    Some(value) => Some(value.to_scalar(env))
    None => None
  }
}

///|
fn optional_attr_bool(
  attr : @core.Attr,
  message : String,
) -> Bool? raise @core.Diagnostic {
  match attr.value {
    Some(value) => Some(value.to_bool(attr.span, message))
    None => None
  }
}

///|
fn rich_text_from_attr(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> (@model.RichContent, String)? raise @core.Diagnostic {
  match attr.value {
    Some(value) => {
      let nodes = title_nodes_from_value(value, env)
      let doc : @core.Document = {
        source: { id: attr.span.source_id, line_offset: 0, column_offset: 0 },
        nodes,
      }
      let content = @content.compile_inline_rich_content(doc, env)
      let fallback_text = @core.value_to_plain_text(value, env~)
      Some((content, fallback_text))
    }
    None => None
  }
}

///|
fn title_nodes_from_value(
  value : @core.Value,
  env : @core.CompileEnv,
) -> Array[@core.Node] {
  match value {
    Scalar(s, span) => [Text(s.to_string(), span)]
    Fragment(nodes, _) => nodes
    Interp(template, span) =>
      match referenced_title_value(template, env) {
        Some(value) => title_nodes_from_value(value, env)
        None => [TextInterp(template, span)]
      }
  }
}

///|
fn referenced_title_value(
  template : @core.Interpolation,
  env : @core.CompileEnv,
) -> @core.Value? {
  match template {
    [Name(name)] => env.lookup_value(name)
    _ => None
  }
}

///|
fn taxon_from_attrs(
  key : String,
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> @model.Taxon raise @core.Diagnostic {
  let mut display : String? = None
  for attr in attrs {
    if attr.name == "taxon-display" {
      let value = optional_attr_scalar(attr, env)
      if value is Some(value) {
        display = Some(value)
      }
    }
  }
  @model.Taxon::new(key, display?)
}
