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
fn slash_path(path : String) -> String {
  path.replace(old="\\", new="/")
}

///|
pub fn dirname(path : String) -> String {
  @posix.Path::dirname(slash_path(path)).to_string()
}

///|
pub fn basename(path : String) -> String {
  @posix.Path::basename(slash_path(path)).to_owned()
}

///|
pub fn join_path(base : String, child : String) -> String {
  @posix.Path::join(normalize_path(base), slash_path(child)).normalize().to_string()
}

///|
pub fn normalize_path(path : String) -> String {
  @posix.Path::normalize(slash_path(path)).to_string()
}

///|
pub fn is_absolute_path(path : String) -> Bool {
  let value : @posix.Path = slash_path(path)
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
    Some(AltDocument)
  } else if has_suffix(path, ".sia") {
    Some(AltLibrary)
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
  if target.length() > 0 && slash_path(target).unsafe_substring(start=0, end=1) == "/" {
    let target = slash_path(target)
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
    slash_path(child_slug).unsafe_substring(start=0, end=1) == "/" {
    let child_slug = slash_path(child_slug)
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

///|
test "logical paths are slash-normalized" {
  @test.assert_eq(normalize_path("math\\a.alt"), "math/a.alt")
  @test.assert_eq(join_path("/repo/site", "trees"), "/repo/site/trees")
  @test.assert_eq(dirname("math/c.alt"), "math")
  @test.assert_eq(basename("a/auto date.sia"), "auto date.sia")
  @test.assert_eq(
    resolve_relative("math/c.alt", "a.alt"),
    "math/a.alt",
  )
  @test.assert_eq(
    resolve_relative("math/deep/c.alt", "../a.alt"),
    "math/a.alt",
  )
  @test.assert_eq(module_name_from_path("a\\auto date.sia"), "auto_date")
}
