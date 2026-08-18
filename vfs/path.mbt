///|
/// A logical path inside the workspace, always POSIX-style.
///
/// All operations accept both `/` and `\` separators and always produce
/// `/`-separated results, so the platform never leaks into logical paths.
pub struct Path(String) derive(Eq, Debug)

///|
pub impl Show for Path with fn output(self : Path, logger : &Logger) -> Unit {
  logger.write_string(self.0)
}

///|
pub fn Path::new(value : String) -> Path {
  Path(value.replace_all(old="\\", new="/"))
}

///|
pub fn Path::to_string(self : Path) -> String {
  self.0
}

///|
pub fn Path::normalize(self : Path) -> Path {
  guard self.0 != "" else { return self }
  let value : @posix.Path = self.0
  Path(value.normalize().to_string())
}

///|
pub fn Path::join(self : Path, child : String) -> Path {
  let lhs : @posix.Path = self.normalize().0
  let rhs : @posix.Path = Path::new(child).0
  Path(lhs.join(rhs).to_string())
}

///|
pub fn Path::dirname(self : Path) -> Path {
  let value : @posix.Path = self.0
  Path(value.dirname().to_string())
}

///|
pub fn Path::basename(self : Path) -> Path {
  let value : @posix.Path = self.0
  Path(value.basename().to_owned())
}

///|
/// Whether the path is absolute: POSIX leading `/` or a Windows drive
/// prefix (`C:/...`), since the CLI resolves entries on the host filesystem.
pub fn Path::is_absolute(self : Path) -> Bool {
  @posix.Path::is_absolute(self.0) || @win32.Path::is_absolute(self.0)
}

///|
pub fn Path::relative(self : Path, base~ : Path) -> Path {
  let value : @posix.Path = self.normalize().0
  let base : @posix.Path = base.normalize().0
  Path(value.relative(base~).to_string())
}

///|
/// Resolves `target` against the directory of this path, or as an
/// absolute path when `target` starts with `/`.
pub fn Path::resolve(self : Path, target : String) -> Path {
  let target = Path::new(target)
  if target.is_absolute() {
    target.normalize()
  } else {
    self.dirname().join(target.0).normalize()
  }
}

///|
pub fn Path::strip_extension(self : Path, extension : String) -> Path {
  if self.0.has_suffix(extension) {
    Path(
      self.0.unsafe_substring(start=0, end=self.0.length() - extension.length()),
    )
  } else {
    self
  }
}

///|
test "logical paths are slash-normalized" {
  @test.assert_eq(Path::new("").normalize().to_string(), "")
  @test.assert_eq(
    Path::new("math\\a.alt").normalize().to_string(),
    "math/a.alt",
  )
  @test.assert_eq(
    Path::new("/repo/site").join("trees").to_string(),
    "/repo/site/trees",
  )
  @test.assert_eq(Path::new("math/c.alt").dirname().to_string(), "math")
  @test.assert_eq(
    Path::new("a/auto date.sia").basename().to_string(),
    "auto date.sia",
  )
  @test.assert_eq(
    Path::new("math/c.alt").resolve("a.alt").to_string(),
    "math/a.alt",
  )
  @test.assert_eq(
    Path::new("math/deep/c.alt").resolve("../a.alt").to_string(),
    "math/a.alt",
  )
  @test.assert_eq(Path::new("/a/b.alt").is_absolute(), true)
  @test.assert_eq(Path::new("C:\\repo\\a.alt").is_absolute(), true)
  @test.assert_eq(Path::new("a/b.alt").is_absolute(), false)
  @test.assert_eq(
    Path::new("/repo/site/trees/a.alt")
    .relative(base=Path::new("/repo/site"))
    .to_string(),
    "trees/a.alt",
  )
  @test.assert_eq(
    Path::new("math/analysis.alt").strip_extension(".alt").to_string(),
    "math/analysis",
  )
}
