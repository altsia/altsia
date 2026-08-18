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
  @posix.Path::join(normalize(base), slash_path(child)).normalize().to_string()
}

///|
pub fn normalize(path : String) -> String {
  @posix.Path::normalize(slash_path(path)).to_string()
}

///|
pub fn is_absolute_path(path : String) -> Bool {
  let value : @posix.Path = slash_path(path)
  value.is_absolute()
}

///|
pub fn strip_extension(path : String, extension : String) -> String {
  if path.has_suffix(extension) {
    path.unsafe_substring(start=0, end=path.length() - extension.length())
  } else {
    path
  }
}

///|
pub fn source_file_kind(path : String) -> SourceFileKind? {
  if path.has_suffix(".alt") || path.has_suffix(".altsia") {
    Some(AltDocument)
  } else if path.has_suffix(".sia") {
    Some(AltLibrary)
  } else {
    None
  }
}

///|
pub fn tree_slug_from_target(
  current_path : String,
  target : String,
) -> TreeSlug {
  let target = slash_path(target)
  if target.has_prefix("/") {
    TreeSlug::parse(target.unsafe_substring(start=1, end=target.length()))
  } else {
    TreeSlug::from_file_path(resolve_relative(current_path, target))
  }
}

///|
pub fn TreeSlug::child(self : TreeSlug, child_slug : String) -> TreeSlug {
  let child_slug = slash_path(child_slug)
  if child_slug.has_prefix("/") {
    TreeSlug::parse(
      child_slug.unsafe_substring(start=1, end=child_slug.length()),
    )
  } else {
    self.sibling(TreeSlug::from_file_path(child_slug))
  }
}

///|
pub fn TreeSlug::anonymous_anchor(self : TreeSlug, index : Int) -> String {
  "\{self.canonical()}-\{index}"
}

///|
pub fn module_name_from_path(path : String) -> String {
  strip_extension(basename(path), ".sia").replace(old=" ", new="_")
}

///|
pub fn resolve_relative(current_path : String, target : String) -> String {
  normalize(join_path(dirname(current_path), target))
}

///|
pub fn TreeSlug::url(self : TreeSlug) -> String {
  let key = self.canonical()
  if key == "index" {
    "index.html"
  } else {
    key + ".html"
  }
}

///|
test "logical paths are slash-normalized" {
  @test.assert_eq(normalize("math\\a.alt"), "math/a.alt")
  @test.assert_eq(join_path("/repo/site", "trees"), "/repo/site/trees")
  @test.assert_eq(dirname("math/c.alt"), "math")
  @test.assert_eq(basename("a/auto date.sia"), "auto date.sia")
  @test.assert_eq(resolve_relative("math/c.alt", "a.alt"), "math/a.alt")
  @test.assert_eq(resolve_relative("math/deep/c.alt", "../a.alt"), "math/a.alt")
  @test.assert_eq(module_name_from_path("a\\auto date.sia"), "auto_date")
}
