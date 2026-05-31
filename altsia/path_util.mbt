///|
fn has_suffix(text : String, suffix : String) -> Bool {
  text.length() >= suffix.length() &&
  text.unsafe_substring(
    start=text.length() - suffix.length(),
    end=text.length(),
  ) ==
  suffix
}

///|
fn dirname(path : String) -> String {
  @path.Path::dirname(path).to_string()
}

///|
fn basename(path : String) -> String {
  @path.Path::basename(path).to_owned()
}

///|
fn join_path(base : String, child : String) -> String {
  @path.Path::join(base, child).normalize().to_string()
}

///|
fn normalize_path(path : String) -> String {
  @path.Path::normalize(path).to_string()
}

///|
fn strip_extension(path : String, extension : String) -> String {
  if has_suffix(path, extension) {
    path.unsafe_substring(start=0, end=path.length() - extension.length())
  } else {
    path
  }
}

///|
fn source_kind(path : String) -> SourceKind? {
  if has_suffix(path, ".alt") {
    Some(Alt)
  } else if has_suffix(path, ".sia") {
    Some(Sia)
  } else {
    None
  }
}

///|
fn section_id_from_path(path : String) -> String {
  strip_extension(normalize_path(path), ".alt")
}

///|
fn module_name_from_path(path : String) -> String {
  strip_extension(basename(path), ".sia").replace(old=" ", new="_")
}

///|
fn resolve_relative(current_path : String, target : String) -> String {
  normalize_path(join_path(dirname(current_path), target))
}

///|
fn url_for_section(id : String) -> String {
  if id == "index" {
    "index.html"
  } else {
    id + ".html"
  }
}
