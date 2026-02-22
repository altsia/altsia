///|
fn forester_app_rewriter_with_context(
  ctx : ProjectContext,
  current_doc_id : String,
  name : @core.Name,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  match name {
    "today" => [@core.Term::Text(@date.today(), loc)]
    "ref" => {
      let split = @core.Stage2Chisel::split_app_args(args)
      rewrite_ref(ctx, current_doc_id, split, loc)
    }
    "metadata" => {
      let split = @core.Stage2Chisel::split_app_args(args)
      
      [@core.Term::App(name, args, loc)]
    }
    _ => [@core.Term::App(name, args, loc)]
  }
}

///|
pub fn forester_app_rewriter(
  name : @core.Name,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  // Backward-compatible stateless default rewriter.
  forester_app_rewriter_with_context(
    ProjectContext::{ docs: Map::new() },
    "",
    name,
    args,
    loc,
  )
}

///|
pub fn ProjectContext::to_forester_rewriter(
  ctx : ProjectContext,
  current_doc_id : String,
) -> @core.AppRewriter {
  (name, args, loc) => {
    forester_app_rewriter_with_context(ctx, current_doc_id, name, args, loc)
  }
}

///|
fn rewrite_ref(
  ctx : ProjectContext,
  current_doc_id : String,
  split : @core.SplitAppArgs,
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
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
