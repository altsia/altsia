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
    LOCAL_LINK_APP_NAME => rewrite_ref(ctx, current_doc_id, args, loc)
    METADATA_APP_NAME => rewrite_metadata(ctx, current_doc_id, args, loc)
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
