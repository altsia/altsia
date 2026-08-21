///|
/// A logical path inside the workspace, always POSIX-style.
///
/// All operations accept both `/` and `\` separators and always produce
/// `/`-separated results, so the platform never leaks into logical paths.
pub struct Path(String) derive(Eq, Debug)

///|
/// A path in canonical form: no `.`/`..` segments, no duplicate separators.
///
/// The invariant is established once at `Path::to_normalized`; every
/// operation on `NormalizedPath` yields another canonical path, so the
/// invariant is preserved structurally.
struct NormalizedPath(String) derive(Eq, Debug)

///|
pub extend NormalizedPath with Eq::{not_equal, equal}

///|
pub extend NormalizedPath with Debug::{to_repr}

///|
pub extend Path with Eq::{not_equal, equal}

///|
pub extend Path with Debug::{to_repr}

///|
pub impl Show for Path with fn output(self : Path, logger : &Logger) -> Unit {
  logger.write_string(self.0)
}

///|
pub extend Path with Show::{output}

///|
pub fn Path::new(value : String) -> Path {
  Path(value.replace_all(old="\\", new="/"))
}

///|
pub fn Path::to_string(self : Path) -> String {
  self.0
}

///|
/// The single normalization entry point.
fn Path::to_normalized(self : Path) -> NormalizedPath {
  guard self.0 != "" else { return NormalizedPath("") }
  let value : @posix.Path = self.0
  NormalizedPath(value.normalize() |> Show::to_string())
}

///|
fn NormalizedPath::to_path(self : NormalizedPath) -> Path {
  Path(self.0)
}

///|
pub fn Path::normalize(self : Path) -> Path {
  self.to_normalized().to_path()
}

///|
fn NormalizedPath::join(
  self : NormalizedPath,
  child : String,
) -> NormalizedPath {
  let lhs : @posix.Path = self.0
  let rhs : @posix.Path = Path::new(child).0
  NormalizedPath(lhs.join(rhs) |> Show::to_string())
}

///|
pub fn Path::join(self : Path, child : String) -> Path {
  self.to_normalized().join(child).to_path()
}

///|
fn NormalizedPath::dirname(self : NormalizedPath) -> NormalizedPath {
  let value : @posix.Path = self.0
  NormalizedPath(value.dirname() |> Show::to_string())
}

///|
pub fn Path::dirname(self : Path) -> Path {
  let value : @posix.Path = self.0
  Path(value.dirname() |> Show::to_string())
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
  let value : @posix.Path = self.to_normalized().0
  let base : @posix.Path = base.to_normalized().0
  Path(value.relative(base~) |> Show::to_string())
}

///|
/// Resolves `target` against the directory of this path, or as an
/// absolute path when `target` starts with `/`.
pub fn Path::resolve(self : Path, target : String) -> Path {
  self.to_normalized().resolve(target).to_path()
}

///|
fn NormalizedPath::resolve(
  self : NormalizedPath,
  target : String,
) -> NormalizedPath {
  let target = Path::new(target)
  if target.is_absolute() {
    target.to_normalized()
  } else {
    self.dirname().join(target.0)
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
    Path::new("//repo//site///trees").normalize().to_string(),
    "/repo/site/trees",
  )
  @test.assert_eq(
    Path::new("math\\a.alt").normalize().to_string(),
    "math/a.alt",
  )
  @test.assert_eq(Path::new("a/./b").normalize().to_string(), "a/b")
  @test.assert_eq(
    Path::new("/repo/site").join("trees\\a.alt").to_string(),
    "/repo/site/trees/a.alt",
  )
  @test.assert_eq(Path::new("/a/b").join("../../c.alt").to_string(), "/c.alt")
  @test.assert_eq(Path::new("a/b").join("../c.alt").to_string(), "a/c.alt")
  @test.assert_eq(Path::new("/repo").join("").to_string(), "/repo")
  @test.assert_eq(Path::new("").join("a/b.alt").to_string(), "a/b.alt")
  @test.assert_eq(Path::new("/a/b/c").dirname().to_string(), "/a/b")
  @test.assert_eq(Path::new("/a/b/").dirname().to_string(), "/a")
  @test.assert_eq(Path::new("a/b/").basename().to_string(), "b")
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
  @test.assert_eq(
    Path::new("math/deep/c.alt").resolve("../../a.alt").to_string(),
    "a.alt",
  )
  @test.assert_eq(
    Path::new("a/b/c.alt").resolve("../../../../d.alt").to_string(),
    "../../d.alt",
  )
  @test.assert_eq(
    Path::new("a/b/c.alt").resolve("/x/y.alt").to_string(),
    "/x/y.alt",
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
    Path::new("/repo/other/a.alt")
    .relative(base=Path::new("/repo/site"))
    .to_string(),
    "../other/a.alt",
  )
  @test.assert_eq(
    Path::new("/repo/site").relative(base=Path::new("/repo/site")).to_string(),
    "",
  )
  @test.assert_eq(
    Path::new("math/analysis.alt").strip_extension(".alt").to_string(),
    "math/analysis",
  )
  @test.assert_eq(
    Path::new("math/analysis.alt.bak").strip_extension(".alt").to_string(),
    "math/analysis.alt.bak",
  )
}
