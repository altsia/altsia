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
pub(all) struct DocEntry {
  id : String
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

///|
fn resolve_ref_target_doc_id(split : @core.SplitAppArgs) -> String? {
  for arg in split.positional {
    if arg is @core.Term::Text(path, _) {
      return Some(path)
    }
  }
  None
}

///|
fn ref_values_to_text(values : Array[@core.Term]) -> String {
  let mut out = ""
  for value in values {
    match value {
      @core.Term::Text(text, _) => out = out + text
      _ => ()
    }
  }
  out
}

///|
fn resolve_ref_text(split : @core.SplitAppArgs) -> String? {
  for named in split.named {
    if named.name == ":text" {
      let text = ref_values_to_text(named.values)
      if !text.is_empty() {
        return Some(text)
      }
    }
  }
  None
}

///|
pub fn ProjectContext::resolve_ref_target_metadata(
  ctx : ProjectContext,
  args : Array[@core.Term],
) -> DocMetadata? {
  let split = @core.Stage2Chisel::split_app_args(args)
  match resolve_ref_target_doc_id(split) {
    Some(target_doc_id) =>
      match ctx.resolve_target_document(target_doc_id) {
        Some(doc) => Some(doc.metadata)
        None => None
      }
    None => None
  }
}
