///|
fn metadata_named_arg_key(name : String) -> String {
  match name.strip_prefix(":") {
    Some(rest) => rest.to_string()
    None => name
  }
}

///|
fn find_metadata_named_arg(
  split : @core.SplitAppArgs,
  key : String,
) -> @core.NamedAppArg? {
  split.get_named(":\{key}")
}

///|
fn resolve_metadata_title(
  ctx : ProjectContext,
  current_doc_id : String,
  split : @core.SplitAppArgs,
  loc : @core.SourceLoc,
) -> @core.Term {
  let fallback = match ctx.get_document(current_doc_id) {
    Some(doc) => doc.title
    None => @core.Term::Text(current_doc_id, loc)
  }
  match find_metadata_named_arg(split, KEY_TITLE) {
    Some(named) =>
      match named.values {
        [] => fallback
        [title] => title
        _ => @core.Term::Splice(named.values, named.loc)
      }
    None => fallback
  }
}

///|
fn metadata_values_to_text(values : Array[@core.Term]) -> String {
  let mut out = ""
  for value in values {
    match value {
      @core.Term::Text(text, _) => out = out + text
      _ => out = out + value.to_string()
    }
  }
  out
}

///|
fn custom_item_term(named : @core.NamedAppArg) -> @core.Term {
  let key = metadata_named_arg_key(named.name)
  match named.values {
    [] => @core.Term::Text(key, named.loc)
    _ => {
      let values : Array[@core.Term] = [@core.Term::Text("\{key}: ", named.loc)]
      values.append(named.values)
      @core.Term::Splice(values, named.loc)
    }
  }
}

///|
fn summary_custom_items(split : @core.SplitAppArgs) -> Array[@core.Term] {
  let items : Array[@core.Term] = []
  for entry in split.named.to_array() {
    let named = entry.1
    let key = metadata_named_arg_key(named.name)
    if !MetadataKey::is_preset(key) {
      items.push(custom_item_term(named))
    }
  }
  items
}

///|
/// Metadata is split into:
/// - preset fields (`title`, `taxon`) with dedicated layout/semantics
/// - `custom_items` for user-defined metadata entries
///
/// `title` and `custom_items` keep Stage2 terms instead of pre-rendered strings.
pub(all) struct Metadata {
  title : @core.Term
  taxon : Taxon?
  custom_items : Array[@core.Term]
}

///|
fn collect_metadata(
  ctx : ProjectContext,
  current_doc_id : String,
  split : @core.SplitAppArgs,
  loc : @core.SourceLoc,
) -> Metadata {
  let title = resolve_metadata_title(ctx, current_doc_id, split, loc)
  let taxon = resolve_metadata_taxon(split)
  let custom_items = summary_custom_items(split)
  Metadata::{ title, taxon, custom_items }
}

///|
fn resolve_metadata_taxon(split : @core.SplitAppArgs) -> Taxon? {
  match find_metadata_named_arg(split, KEY_TAXON) {
    Some(named) => {
      let text = metadata_values_to_text(named.values)
      if text.is_empty() {
        None
      } else {
        Some(Taxon::{ numbering: None, text })
      }
    }
    None => None
  }
}

///|
fn rewrite_metadata(
  ctx : ProjectContext,
  current_doc_id : String,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  let split = @core.Stage2Chisel::split_app_args(args)
  let metadata = collect_metadata(ctx, current_doc_id, split, loc)
  [
    term_section_summary(
      metadata.taxon,
      metadata.title,
      metadata.custom_items,
      loc,
    ),
  ]
}

///|
fn rewrite_ref(
  ctx : ProjectContext,
  current_doc_id : String,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  let split = @core.Stage2Chisel::split_app_args(args)
  let target_doc_id = resolve_ref_target_doc_id(split)
  let target_doc = target_doc_id.bind(doc_id => {
    ctx.resolve_target_document(doc_id, current_doc_id~)
  })
  let href = target_doc_id.unwrap_or("")
  let title = target_doc.map(doc => doc.title_with_slug())
  let content = resolve_ref_text(split).map_or_else(
    () => target_doc.map_or(@core.Term::Text(href, loc), doc => doc.title),
    text => @core.Term::Text(text, loc),
  )
  [build_ref_anchor_shape(href, content, title, loc)]
}

///|
fn build_ref_anchor_shape(
  href : String,
  content : @core.Term,
  title : String?,
  loc : @core.SourceLoc,
) -> @core.Term {
  let anchor_attrs : Array[@core.Term] = [hattr("href", href, loc)]
  for value in title.iter() {
    anchor_attrs.push(hattr("title", value, loc))
  }
  hel("span", loc, attrs=[hclass(["link", "local"], loc)], children=[
    hel("a", loc, attrs=anchor_attrs, children=[content]),
  ])
}
