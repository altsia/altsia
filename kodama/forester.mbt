// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn forester_app_rewriter_with_context(
  ctx : ProjectContext,
  current_id : String,
  name : @core.Name,
  args : Array[@core.Term],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  match name {
    "today" => [@core.Term::Text(@date.today(), loc)]
    LOCAL_LINK_APP_NAME => rewrite_local_link(ctx, current_id, args, loc)
    METADATA_APP_NAME => rewrite_metadata(ctx, current_id, args, loc)
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
  current_id : String,
) -> @core.AppRewriter {
  (name, args, loc) => {
    forester_app_rewriter_with_context(ctx, current_id, name, args, loc)
  }
}
