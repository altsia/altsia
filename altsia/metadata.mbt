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
  env : @core.CompileEnv,
  allow_slug_override? : Bool = true,
) -> Result[Metadata, @core.Diagnostic] {
  let mut metadata = default_metadata(slug, source_id)
  metadata = match
    apply_metadata_attrs(metadata, doc.nodes, env, allow_slug_override~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(metadata)
}

///|
fn metadata_from_tree(
  slug : TreeSlug,
  source_id : String,
  attrs : Array[@core.Attr],
  doc : @core.Document,
  env : @core.CompileEnv,
) -> Result[Metadata, @core.Diagnostic] {
  let mut metadata = default_metadata(slug, source_id)
  metadata = match apply_tree_attrs(metadata, attrs, env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  metadata = match
    apply_metadata_attrs(metadata, doc.nodes, env, allow_slug_override=false) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(metadata)
}

///|
fn apply_tree_attrs(
  metadata : Metadata,
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Result[Metadata, @core.Diagnostic] {
  let mut result = metadata
  for attr in attrs {
    match attr.name {
      "lang" =>
        match attr_scalar(attr) {
          Some(value) => result = { ..result, lang: Some(value) }
          None => ()
        }
      "title" =>
        match rich_text_from_attr(attr, env) {
          Ok(Some(value)) => result = { ..result, title: Some(value) }
          Ok(None) => ()
          Err(error) => return Err(error)
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
  Ok(result)
}

///|
fn apply_metadata_attrs(
  metadata : Metadata,
  nodes : Array[@core.Node],
  env : @core.CompileEnv,
  allow_slug_override~ : Bool,
) -> Result[Metadata, @core.Diagnostic] {
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
              match rich_text_from_attr(attr, env) {
                Ok(Some(value)) => metadata = { ..metadata, title: Some(value) }
                Ok(None) => ()
                Err(error) => return Err(error)
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
  Ok(metadata)
}

///|
fn rich_text_from_attr(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> Result[(GraphContent, String)?, @core.Diagnostic] {
  match attr.value {
    Some(value) => {
      let nodes = title_nodes_from_value(value, env)
      let doc : @core.Document = {
        source: { id: attr.span.source_id, line_offset: 0, column_offset: 0 },
        nodes,
      }
      match compile_inline_graph_content(doc, env) {
        Ok(content) =>
          Ok(Some((content, value_fallback_text(value, env))))
        Err(error) => Err(error)
      }
    }
    None => Ok(None)
  }
}

///|
fn title_nodes_from_value(
  value : @core.Value,
  env : @core.CompileEnv,
) -> Array[@core.Node] {
  match value {
    Scalar(text, span) => [Text(text, span)]
    Bool(value, span) => [Text(value.to_string(), span)]
    Fragment(nodes, _) => nodes
    Interp(template, span) =>
      match exact_interpolation_name(template) {
        Some(name) =>
          match env.lookup_value(name) {
            Some(value) => title_nodes_from_value(value, env)
            None => [TextInterp(template, span)]
          }
        None => [TextInterp(template, span)]
      }
  }
}

///|
fn value_fallback_text(value : @core.Value, env : @core.CompileEnv) -> String {
  match value {
    Scalar(text, _) => text
    Bool(value, _) => value.to_string()
    Fragment(nodes, _) => nodes_fallback_text(nodes, env)
    Interp(template, _) => interpolate_fallback_text(template, env)
  }
}

///|
fn nodes_fallback_text(
  nodes : Array[@core.Node],
  env : @core.CompileEnv,
) -> String {
  let parts : Array[String] = []
  for node in nodes {
    match node {
      Text(text, _) => parts.push(text)
      TextInterp(template, _) =>
        parts.push(interpolate_fallback_text(template, env))
      Element(_, _, children, _) =>
        parts.push(nodes_fallback_text(children, env))
      Ref(name, _) =>
        match env.lookup_value(name) {
          Some(value) => parts.push(value_fallback_text(value, env))
          None => parts.push(name)
        }
      _ => ()
    }
  }
  normalize_fallback_text(parts.join(""))
}

///|
fn normalize_fallback_text(text : String) -> String {
  let mut result = text.trim().to_owned()
  while result.contains("  ") {
    result = result.replace(old="  ", new=" ")
  }
  result
}

///|
fn interpolate_fallback_text(
  template : String,
  env : @core.CompileEnv,
) -> String {
  let chars = template.to_array()
  let parts : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '(' {
      let mut end = index + 1
      while end < chars.length() && chars[end] != ')' {
        end += 1
      }
      if end >= chars.length() {
        parts.push(String::from_array(chars.view(start=index)))
        index = chars.length()
      } else {
        let name = String::from_array(chars.view(start=index + 1, end~))
        match env.lookup_value(name) {
          Some(value) => parts.push(value_fallback_text(value, env))
          None => parts.push("(" + name + ")")
        }
        index = end + 1
      }
    } else {
      let start = index
      while index < chars.length() && chars[index] != '(' {
        index += 1
      }
      parts.push(String::from_array(chars.view(start~, end=index)))
    }
  }
  parts.join("")
}

///|
fn exact_interpolation_name(template : String) -> String? {
  let chars = template.to_array()
  if chars.length() < 3 || chars[0] != '(' || chars[chars.length() - 1] != ')' {
    return None
  }
  for i in 1..<(chars.length() - 1) {
    if chars[i] == '(' || chars[i] == ')' {
      return None
    }
  }
  Some(String::from_array(chars.view(start=1, end=chars.length() - 1)))
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
  match tree.metadata.page_title {
    Some(value) => value
    None =>
      match tree.metadata.title {
        Some((_, fallback_text)) => fallback_text
        None => tree.slug.canonical()
      }
  }
}

///|
fn tree_page_title(tree : CompiledTree) -> String? {
  match tree.metadata.page_title {
    Some(value) => Some(value)
    None =>
      match tree.metadata.title {
        Some((_, fallback_text)) => Some(fallback_text)
        None => None
      }
  }
}
