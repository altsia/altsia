///|
pub(all) struct ProjectContext {
  docs : Map[String, IndexedDocument]
}

///|
fn workspace_has_leading_slash(path : String) -> Bool {
  if path.is_empty() {
    return false
  }
  let ch = path.get_char(0).unwrap()
  ch == '/' || ch == '\\'
}

///|
fn workspace_strip_leading_slashes(path : String) -> String {
  let mut start = 0
  while start < path.length() {
    let ch = path.get_char(start).unwrap()
    if ch != '/' && ch != '\\' {
      break
    }
    start += 1
  }
  if start == 0 {
    path
  } else {
    path.unsafe_substring(start=start, end=path.length())
  }
}

///|
fn normalize_workspace_path(path : String) -> String {
  let absolute = workspace_has_leading_slash(path)
  let mut segment = ""
  let segments : Array[String] = []
  let mut segment_count = 0

  for i in 0..=path.length() {
    let is_end = i == path.length()
    let ch = if is_end { '/' } else { path.get_char(i).unwrap() }
    let is_sep = ch == '/' || ch == '\\'
    if !is_sep {
      segment = segment + ch.to_string()
      continue
    }

    if segment.is_empty() || segment == "." {
      segment = ""
      continue
    }

    if segment == ".." {
      if segment_count > 0 && segments[segment_count - 1] != ".." {
        segment_count -= 1
      } else if !absolute {
        if segment_count < segments.length() {
          segments[segment_count] = segment
        } else {
          segments.push(segment)
        }
        segment_count += 1
      }
      segment = ""
      continue
    }

    if segment_count < segments.length() {
      segments[segment_count] = segment
    } else {
      segments.push(segment)
    }
    segment_count += 1
    segment = ""
  }

  let mut body = ""
  for i in 0..<segment_count {
    if i > 0 {
      body = body + "/"
    }
    body = body + segments[i]
  }
  if absolute {
    if body.is_empty() { "/" } else { "/" + body }
  } else {
    body
  }
}

///|
fn workspace_dir_path(path : String) -> String {
  let normalized = normalize_workspace_path(path)
  let mut last_slash = -1
  for i in 0..<normalized.length() {
    if normalized.get_char(i).unwrap() == '/' {
      last_slash = i
    }
  }
  if last_slash < 0 {
    ""
  } else if last_slash == 0 {
    "/"
  } else {
    normalized.unsafe_substring(start=0, end=last_slash)
  }
}

///|
fn resolve_ref_target_workspace_path(
  target : String,
  current_doc_id : String,
) -> String {
  let target = normalize_workspace_path(target)
  let is_relative = !target.is_empty() &&
    !workspace_has_leading_slash(target) &&
    !target.contains(":")
  if !is_relative || current_doc_id.is_empty() {
    return target
  }
  let base_dir = workspace_dir_path(current_doc_id)
  if base_dir.is_empty() {
    normalize_workspace_path(target)
  } else {
    normalize_workspace_path("\{base_dir}/\{target}")
  }
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
fn push_unique_non_empty(values : Array[String], value : String) -> Unit {
  if value.is_empty() {
    return
  }
  if !values.contains(value) {
    values.push(value)
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
  current_doc_id? : String = "",
) -> IndexedDocument? {
  let workspace_target = resolve_ref_target_workspace_path(
    target,
    current_doc_id,
  )
  let normalized = ref_target_to_doc_id_candidate(workspace_target)
  let candidates : Array[String] = []
  push_unique_non_empty(candidates, normalized)
  if !normalized.contains(".") {
    push_unique_non_empty(candidates, normalized + ".alt")
  }

  let stripped = workspace_strip_leading_slashes(normalized)
  if stripped != normalized {
    push_unique_non_empty(candidates, stripped)
    if !stripped.contains(".") {
      push_unique_non_empty(candidates, stripped + ".alt")
    }
  } else {
    push_unique_non_empty(candidates, "/" + normalized)
    if !normalized.contains(".") {
      push_unique_non_empty(candidates, "/" + normalized + ".alt")
    }
  }

  for candidate in candidates {
    match ctx.docs.get(candidate) {
      Some(doc) => return Some(doc)
      None => ()
    }
  }

  let slug_candidate = ref_target_to_slug_candidate(workspace_target)
  let stripped_slug = workspace_strip_leading_slashes(slug_candidate)
  for entry in ctx.docs.to_array() {
    let doc = entry.1
    if doc.slug == slug_candidate ||
      doc.slug == stripped_slug ||
      workspace_strip_leading_slashes(doc.slug) == stripped_slug {
      return Some(doc)
    }
  }
  None
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
  current_doc_id? : String = "",
) -> DocMetadata? {
  let split = @core.Stage2Chisel::split_app_args(args)
  match resolve_ref_target_doc_id(split) {
    Some(target_doc_id) =>
      match ctx.resolve_target_document(target_doc_id, current_doc_id~) {
        Some(doc) => Some(doc.metadata)
        None => None
      }
    None => None
  }
}
