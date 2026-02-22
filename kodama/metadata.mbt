///|
pub(all) struct RawMetadataPreset {
  title : @core.NamedAppArg?
  page_title : @core.NamedAppArg?
  taxon : @core.NamedAppArg?
} derive(Eq, Show, Debug)

///|
pub(all) struct RawMetadata {
  preset : RawMetadataPreset
  custom : Map[String, @core.NamedAppArg]
} derive(Eq, Show, Debug)

///|
pub fn strip_named_key_prefix(name : String) -> String {
  match @core.Stage2::extract_named_param(name) {
    Some(rest) => rest.to_string()
    None => name
  }
}

///|
fn metadata_build_from_named_map(
  named : Map[String, @core.NamedAppArg],
) -> RawMetadata {
  let mut title : @core.NamedAppArg? = None
  let mut page_title : @core.NamedAppArg? = None
  let mut taxon : @core.NamedAppArg? = None
  let custom : Map[String, @core.NamedAppArg] = Map::new()

  for entry in named.to_array() {
    let key = strip_named_key_prefix(entry.0)
    let value = entry.1
    match key {
      KEY_TITLE => title = Some(value)
      KEY_PAGE_TITLE => page_title = Some(value)
      KEY_TAXON => taxon = Some(value)
      _ => {
        guard MetadataKey::is_preset(key) else { custom[entry.0] = value }
        continue
      }
    }
  }

  RawMetadata::{
    preset: RawMetadataPreset::{ title, page_title, taxon },
    custom,
  }
}

///|
pub fn extract_raw_metadata_from_metadata_args(
  args : Array[@core.Term],
) -> RawMetadata {
  let split = @core.Stage2Chisel::split_app_args(args)
  metadata_build_from_named_map(split.named)
}

///|
fn raw_metadata_empty() -> RawMetadata {
  metadata_build_from_named_map(Map::new())
}

///|
pub fn extract_raw_metadata_from_terms(
  terms : Array[@core.Term],
) -> RawMetadata {
  for term in terms {
    match term {
      @core.Term::App("metadata", args, _) =>
        // Forester design rule: one document has at most one metadata app.
        return extract_raw_metadata_from_metadata_args(args)
      _ => ()
    }
  }
  raw_metadata_empty()
}

///|
pub fn RawMetadata::get(
  metadata : RawMetadata,
  key : String,
) -> @core.NamedAppArg? {
  let lookup = normalize_named_arg_key(key)
  match lookup {
    _ if lookup == ":\{KEY_TITLE}" => metadata.preset.title
    _ if lookup == ":\{KEY_PAGE_TITLE}" => metadata.preset.page_title
    _ if lookup == ":\{KEY_TAXON}" => metadata.preset.taxon
    _ => metadata.custom.get(lookup)
  }
}

///|
pub fn RawMetadata::get_plain_text(
  metadata : RawMetadata,
  key : String,
) -> String? {
  metadata
  .get(key)
  .bind(named => {
    let text = terms_plain_text(named.values)
    ite_eager(text.is_empty(), None, Some(text))
  })
}

///|
fn metadata_named_arg_to_term(
  named : @core.NamedAppArg,
  fallback : @core.Term,
) -> @core.Term {
  match named.values {
    [] => fallback
    [term] => term
    _ => @core.Term::Splice(named.values, named.loc)
  }
}

///|
pub fn RawMetadata::title_term(
  metadata : RawMetadata,
  fallback : @core.Term,
) -> @core.Term {
  match metadata.preset.title {
    Some(named) => metadata_named_arg_to_term(named, fallback)
    None => fallback
  }
}

///|
fn metadata_values_text(values : Array[@core.Term]) -> String {
  let plain = terms_plain_text(values)
  if !plain.is_empty() {
    return plain
  }
  values.map(value => value.to_string()).fold(init="", (a, b) => a + b)
}

///|
pub fn RawMetadata::taxon_text(metadata : RawMetadata) -> String? {
  match metadata.preset.taxon {
    Some(named) => {
      let text = metadata_values_text(named.values)
      ite_eager(text.is_empty(), None, Some(text))
    }
    None => None
  }
}

///|
pub fn RawMetadata::custom_items(
  metadata : RawMetadata,
) -> Array[@core.NamedAppArg] {
  metadata.custom.to_array().map(entry => entry.1)
}
