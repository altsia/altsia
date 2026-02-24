// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn resolve_metadata_title(
  ctx : ProjectContext,
  current_id : String,
  raw : RawMetadata,
  loc : @core.SourceLoc,
) -> @core.Term {
  let fallback = match ctx.get_document(current_id) {
    Some(doc) => doc.title
    None => @core.Term::Text(current_id, loc)
  }
  raw.title_term(fallback)
}

///|
fn custom_item_term(named : @core.NamedAppArg) -> @core.Term {
  match named.values {
    [] => @core.Term::Text("", named.loc)
    _ => @core.Term::Splice(named.values, named.loc)
  }
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
  current_id : String,
  raw : RawMetadata,
  loc : @core.SourceLoc,
) -> Metadata {
  let title = resolve_metadata_title(ctx, current_id, raw, loc)
  let taxon = resolve_metadata_taxon(raw)
  let custom_items = raw.custom_items().map(custom_item_term)
  Metadata::{ title, taxon, custom_items }
}

///|
fn resolve_metadata_taxon(raw : RawMetadata) -> Taxon? {
  raw.taxon_text().map(text => Taxon::{ numbering: None, text })
}

///|
fn rewrite_metadata(
  ctx : ProjectContext,
  current_id : String,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  let raw = extract_raw_metadata_from_metadata_args(args)
  let metadata = collect_metadata(ctx, current_id, raw, loc)
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
fn rewrite_local_link(
  ctx : ProjectContext,
  current_id : String,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  let split = @core.Stage2Chisel::split_app_args(args)
  let target_path = resolve_local_link_target_path(split)
  let target_doc = target_path.bind(path => {
    ctx.resolve_target_document(path, current_id~)
  })
  let href = target_path.unwrap_or("")
  let title = target_doc.map(doc => doc.title_with_slug())
  let content = resolve_local_link_text(split).map_or_else(
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
  anchor_attrs.append(
    title.map_or_else(() => [], value => [hattr("title", value, loc)]),
  )
  hel("span", loc, attrs=[hclass(["link", "local"], loc)], children=[
    hel("a", loc, attrs=anchor_attrs, children=[content]),
  ])
}
