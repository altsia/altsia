///|
pub(all) struct ProjectContext {
  docs : Map[String, IndexedDocument]
}

///|
fn ref_target_to_doc_id_candidate(target : String) -> String {
  if target.has_suffix(".md") {
    let stem = target.unsafe_substring(start=0, end=target.length() - 3)
    stem + ".alt"
  } else {
    target
  }
}

///|
fn ref_target_to_slug_candidate(target : String) -> String {
  let normalized = ref_target_to_doc_id_candidate(target)
  let mut slash_index = -1
  let mut dot_index = -1
  for i in 0..<normalized.length() {
    let ch = normalized.get_char(i).unwrap()
    if ch == '/' || ch == '\\' {
      slash_index = i
      dot_index = -1
      continue
    }
    if ch == '.' {
      dot_index = i
    }
  }
  if dot_index > slash_index {
    normalized.unsafe_substring(start=0, end=dot_index)
  } else {
    normalized
  }
}

///|
pub fn forester_build_project_context(
  docs : Array[(String, String)],
) -> ProjectContext raise {
  let indexed : Map[String, IndexedDocument] = Map::new()
  for entry in docs {
    let doc_id = entry.0
    let source = entry.1
    indexed[doc_id] = forester_index_document(doc_id, source)
  }
  ProjectContext::{ docs: indexed }
}

///|
pub fn ProjectContext::get_document(
  ctx : ProjectContext,
  doc_id : String,
) -> IndexedDocument? {
  ctx.docs.get(doc_id)
}

///|
pub fn ProjectContext::resolve_target_document(
  ctx : ProjectContext,
  target : String,
) -> IndexedDocument? {
  let normalized = ref_target_to_doc_id_candidate(target)
  match ctx.docs.get(normalized) {
    Some(doc) => Some(doc)
    None => {
      if !normalized.contains(".") {
        match ctx.docs.get(normalized + ".alt") {
          Some(doc) => return Some(doc)
          None => ()
        }
      }
      let slug_candidate = ref_target_to_slug_candidate(target)
      for entry in ctx.docs.to_array() {
        let doc = entry.1
        if doc.slug == slug_candidate {
          return Some(doc)
        }
      }
      None
    }
  }
}

///|
pub fn ProjectContext::get_metadata(
  ctx : ProjectContext,
  doc_id : String,
) -> DocMetadata? {
  match ctx.docs.get(doc_id) {
    Some(doc) => Some(doc.metadata)
    None => None
  }
}
