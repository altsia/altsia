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
  split.get_named(key)
}

///|
fn resolve_metadata_title(
  ctx : ProjectContext,
  current_doc_id : String,
  split : @core.SplitAppArgs,
) -> String {
  let fallback = match ctx.get_document(current_doc_id) {
    Some(doc) => doc.title
    None => current_doc_id
  }
  match find_metadata_named_arg(split, KEY_TITLE) {
    Some(named) => {
      let title = ref_values_to_text(named.values)
      if title.is_empty() {
        fallback
      } else {
        title
      }
    }
    None => fallback
  }
}

///|
fn resolve_metadata_taxon(split : @core.SplitAppArgs) -> Taxon? {
  match find_metadata_named_arg(split, KEY_TAXON) {
    Some(named) => {
      let text = ref_values_to_text(named.values)
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
fn summary_metadata_items(split : @core.SplitAppArgs) -> Array[HtmlTermNode] {
  let items : Array[HtmlTermNode] = []
  for named in split.named_entries {
    let key = metadata_named_arg_key(named.name)
    if is_fancy_metadata(key) {
      continue
    }
    let value = ref_values_to_text(named.values)
    let text = if value.is_empty() { key } else { "\{key}: \{value}" }
    items.push(htext(text))
  }
  items
}

///|
fn rewrite_metadata(
  ctx : ProjectContext,
  current_doc_id : String,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  let split = @core.Stage2Chisel::split_app_args(args)
  let title = resolve_metadata_title(ctx, current_doc_id, split)
  let taxon = resolve_metadata_taxon(split)
  let metadata_items = summary_metadata_items(split)
  [term_section_summary(taxon, htext(title), metadata_items).to_term(loc)]
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
    () => target_doc.map_or(href, doc => doc.title),
    text => text,
  )
  [build_ref_anchor_shape(href, content, title, loc)]
}

///|
fn build_ref_anchor_shape(
  href : String,
  content : String,
  title : String?,
  loc : @core.SourceLoc,
) -> @core.Term {
  let anchor_attrs : Array[(String, String)] = [html_attr("href", href)]
  for value in title.iter() {
    anchor_attrs.push(html_attr("title", value))
  }
  hel("span", attrs=[hclass(["link", "local"])], children=[
    hel("a", attrs=anchor_attrs, children=[htext(content)]),
  ]).to_term(loc)
}
