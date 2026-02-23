pub fn path_to_slug(path : @path.Path) -> String {
  let text = path.as_string()
  let mut slash_index = -1
  let mut dot_index = -1
  for i in 0..<text.length() {
    let ch = text.get_char(i).unwrap()
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
    text.unsafe_substring(start=0, end=dot_index)
  } else {
    text
  }
}

///|
fn resolve_workspace_target_path(
  target_path : String,
  current_id : String,
) -> @path.Path {
  let target_path = @path.Path::new(target_path)
  if current_id.is_empty() || !target_path.is_relative() {
    target_path
  } else {
    @path.Path::new(current_id).parent().join(target_path)
  }
}
