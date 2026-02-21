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
      let _current_doc = ctx.get_document(current_doc_id)
      let split = @core.Stage2Chisel::split_app_args(args)
      let target_doc_id = resolve_ref_target_doc_id(split)
      let target_doc = match target_doc_id {
        Some(target_doc_id) => ctx.resolve_target_document(target_doc_id)
        None => None
      }
      let href = match target_doc_id {
        Some(target_doc_id) => target_doc_id
        None => ""
      }
      let title = match target_doc {
        Some(doc) => Some(doc.title_with_slug())
        None => None
      }
      let content = match resolve_ref_text(split) {
        Some(text) => text
        None =>
          match target_doc {
            Some(doc) => doc.title
            None => href
          }
      }
      [build_ref_anchor_shape(href, content, title, loc)]
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
fn build_ref_anchor_shape(
  href : String,
  content : String,
  title : String?,
  loc : @core.SourceLoc,
) -> @core.Term {
  let args : Array[@core.Term] = [
    @core.Term::App(":href", [@core.Term::Text(href, loc)], loc),
  ]
  match title {
    Some(title) =>
      args.push(@core.Term::App(":title", [@core.Term::Text(title, loc)], loc))
    None => ()
  }
  args.push(@core.Term::Text(content, loc))
  @core.Term::App("a", args, loc)
}
