///|
/// A tree slug is the workspace-relative path of a tree without its
/// source extension, e.g. `math/analysis` from `math/analysis.alt`.
pub struct TreeSlug {
  segments : Array[String]
} derive(Eq, Debug)

///|
pub fn TreeSlug::parse(value : String) -> TreeSlug {
  let normalized = @vfs.Path::new(value).normalize().to_string()
  let path = if normalized.has_prefix("/") {
    normalized.unsafe_substring(start=1, end=normalized.length())
  } else {
    normalized
  }
  {
    segments: path
    .split("/")
    .map(view => view.to_owned())
    .filter(segment => segment != "" && segment != ".")
    .to_array(),
  }
}

///|
pub fn TreeSlug::from_file_path(path : String) -> TreeSlug {
  let normalized = @vfs.Path::new(path).normalize()
  if normalized.to_string().has_suffix(".altsia") {
    TreeSlug::parse(normalized.strip_extension(".altsia").to_string())
  } else {
    TreeSlug::parse(normalized.strip_extension(".alt").to_string())
  }
}

///|
pub fn TreeSlug::canonical(self : TreeSlug) -> String {
  self.segments.join("/")
}

///|
pub fn TreeSlug::sibling(self : TreeSlug, child : TreeSlug) -> TreeSlug {
  let segments = if self.segments.length() > 1 {
    self.segments[:self.segments.length() - 1].to_owned()
  } else {
    []
  }
  segments.append(child.segments)
  { segments, }
}

///|
pub fn TreeSlug::child(self : TreeSlug, child_slug : String) -> TreeSlug {
  let child_slug = @vfs.Path::new(child_slug).normalize().to_string()
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
pub fn TreeSlug::url(self : TreeSlug) -> String {
  let key = self.canonical()
  if key == "index" {
    "index.html"
  } else {
    key + ".html"
  }
}

///|
pub fn tree_slug_from_target(
  current_path : String,
  target : String,
) -> TreeSlug {
  let target = @vfs.Path::new(target).normalize().to_string()
  if target.has_prefix("/") {
    TreeSlug::parse(target.unsafe_substring(start=1, end=target.length()))
  } else {
    TreeSlug::from_file_path(
      @vfs.Path::new(current_path).resolve(target).to_string(),
    )
  }
}

///|
test "slugs are normalized workspace paths" {
  @test.assert_eq(
    TreeSlug::parse("/math/analysis").canonical(),
    "math/analysis",
  )
  @test.assert_eq(TreeSlug::parse("math/analysis").canonical(), "math/analysis")
  @test.assert_eq(
    TreeSlug::from_file_path("math\\analysis.alt").canonical(),
    "math/analysis",
  )
  @test.assert_eq(
    TreeSlug::from_file_path("math/analysis.altsia").canonical(),
    "math/analysis",
  )
  @test.assert_eq(
    TreeSlug::parse("math/analysis").child("deeper.alt").canonical(),
    "math/deeper",
  )
  @test.assert_eq(
    TreeSlug::parse("math").child("/deeper").canonical(),
    "deeper",
  )
  @test.assert_eq(TreeSlug::parse("math").anonymous_anchor(3), "math-3")
  @test.assert_eq(TreeSlug::parse("index").url(), "index.html")
  @test.assert_eq(TreeSlug::parse("math/analysis").url(), "math/analysis.html")
  @test.assert_eq(
    tree_slug_from_target("math/analysis.alt", "../foundations.alt").canonical(),
    "foundations",
  )
  @test.assert_eq(
    tree_slug_from_target("math/analysis.alt", "/foundations").canonical(),
    "foundations",
  )
}
