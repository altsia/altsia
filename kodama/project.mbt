///|
pub(all) struct ProjectContext {
  docs : Map[DocumentId, IndexedDocument]
}

///|
pub(all) struct DocEntry {
  id : DocumentId
  content : String
}

///|
pub fn forester_build_project_context(
  docs : Array[DocEntry],
) -> ProjectContext raise {
  let indexed : Map[String, IndexedDocument] = Map::new()
  for entry in docs {
    indexed[entry.id] = forester_index_document(entry.id, entry.content)
  }
  ProjectContext::{ docs: indexed }
}

///|
pub fn ProjectContext::get_document(
  ctx : ProjectContext,
  id : DocumentId,
) -> IndexedDocument? {
  ctx.docs.get(id)
}

///|
pub fn ProjectContext::resolve_target_document(
  ctx : ProjectContext,
  target_path : String,
  current_id? : DocumentId = "",
) -> IndexedDocument? {
  let workspace_target = resolve_workspace_target_path(target_path, current_id)
  let id = workspace_target.strip_leading_slashes().as_string()
  guard !id.is_empty() else { None }
  ctx.docs.get(id)
}

///|
pub fn ProjectContext::get_metadata(
  ctx : ProjectContext,
  id : String,
) -> RawMetadata? {
  ctx.docs.get(id).map(doc => doc.metadata)
}

///|
fn resolve_local_link_target_path(split : @core.SplitAppArgs) -> String? {
  for arg in split.positional {
    if arg is @core.Term::Text(path, _) {
      return Some(path)
    }
  }
  None
}

///|
pub fn ProjectContext::resolve_ref_target_metadata(
  ctx : ProjectContext,
  args : Array[@core.Term],
  current_id? : String = "",
) -> RawMetadata? {
  let split = @core.Stage2Chisel::split_app_args(args)
  resolve_local_link_target_path(split)
  .bind(target_path => ctx.resolve_target_document(target_path, current_id~))
  .map(doc => doc.metadata)
}
