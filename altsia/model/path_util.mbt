///|
pub fn has_suffix(text : String, suffix : String) -> Bool {
  text.length() >= suffix.length() &&
  text.unsafe_substring(
    start=text.length() - suffix.length(),
    end=text.length(),
  ) ==
  suffix
}

///|
pub fn dirname(path : String) -> String {
  @path.Path::dirname(path).to_string()
}

///|
pub fn basename(path : String) -> String {
  @path.Path::basename(path).to_owned()
}

///|
pub fn join_path(base : String, child : String) -> String {
  @path.Path::join(base, child).normalize().to_string()
}

///|
pub fn normalize_path(path : String) -> String {
  @path.Path::normalize(path).to_string()
}

///|
pub fn is_absolute_path(path : String) -> Bool {
  let value : @path.Path = path
  value.is_absolute()
}

///|
pub fn strip_extension(path : String, extension : String) -> String {
  if has_suffix(path, extension) {
    path.unsafe_substring(start=0, end=path.length() - extension.length())
  } else {
    path
  }
}

///|
pub fn source_file_kind(path : String) -> SourceFileKind? {
  if has_suffix(path, ".alt") || has_suffix(path, ".altsia") {
    Some(Alt)
  } else if has_suffix(path, ".sia") {
    Some(Sia)
  } else {
    None
  }
}

///|
pub fn tree_slug_from_path(path : String) -> TreeSlug {
  TreeSlug::from_file_path(path)
}

///|
pub fn tree_slug_from_target(
  current_path : String,
  target : String,
) -> TreeSlug {
  if target.length() > 0 && target.unsafe_substring(start=0, end=1) == "/" {
    TreeSlug::parse(target.unsafe_substring(start=1, end=target.length()))
  } else {
    tree_slug_from_path(resolve_relative(current_path, target))
  }
}

///|
pub fn child_tree_slug(
  top_level_slug : TreeSlug,
  child_slug : String,
) -> TreeSlug {
  if child_slug.length() > 0 &&
    child_slug.unsafe_substring(start=0, end=1) == "/" {
    TreeSlug::parse(
      child_slug.unsafe_substring(start=1, end=child_slug.length()),
    )
  } else {
    top_level_slug.sibling(tree_slug_from_path(child_slug))
  }
}

///|
pub fn anonymous_tree_anchor(top_level_slug : TreeSlug, index : Int) -> String {
  top_level_slug.canonical() + "-" + index.to_string()
}

///|
pub fn module_name_from_path(path : String) -> String {
  strip_extension(basename(path), ".sia").replace(old=" ", new="_")
}

///|
pub fn resolve_relative(current_path : String, target : String) -> String {
  normalize_path(join_path(dirname(current_path), target))
}

///|
pub fn url_for_tree(slug : TreeSlug) -> String {
  let key = slug.canonical()
  if key == "index" {
    "index.html"
  } else {
    key + ".html"
  }
}
