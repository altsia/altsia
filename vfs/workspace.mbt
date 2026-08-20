///|
/// A workspace is a virtual filesystem rooted at an arbitrary root
/// path. Every logical path inside the workspace is POSIX-normalized,
/// regardless of the host platform.

///|
pub struct Workspace {
  root : Path
} derive(Eq, Debug)

///|
pub extend Workspace with Eq::{not_equal, equal}

///|
pub extend Workspace with Debug::{to_repr}

///|
pub fn Workspace::new(root : String) -> Workspace {
  { root: Path::new(root).normalize() }
}

///|
pub fn Workspace::root(self : Workspace) -> Path {
  self.root
}

///|
/// Whether the workspace has no root: paths are treated as already
/// relative to the workspace itself.
fn Workspace::is_empty(self : Workspace) -> Bool {
  self.root.to_string() == ""
}

///|
/// Resolves a path inside the workspace: absolute paths are normalized
/// as-is, relative paths are joined onto the workspace root.
pub fn Workspace::abs(self : Workspace, path : String) -> Path {
  let path = Path::new(path)
  guard !path.is_absolute() else { path.normalize() }
  self.root.join(path.to_string())
}

///|
/// The path relative to the workspace root, or `None` when the path
/// escapes the workspace.
pub fn Workspace::relative(self : Workspace, path : String) -> String? {
  let value = self.abs(path).to_string()
  let root = self.root.to_string()
  guard !self.is_empty() else { return Some(value) }
  guard value != root else { return Some("") }
  let prefix = root + "/"
  guard value.has_prefix(prefix) else { None }
  Some(value.unsafe_substring(start=prefix.length(), end=value.length()))
}

///|
pub fn Workspace::contains(self : Workspace, path : String) -> Bool {
  self.relative(path) is Some(_)
}

///|
test "workspace resolves absolute and relative paths" {
  let ws = Workspace::new("/repo/site")
  @test.assert_eq(ws.root().to_string(), "/repo/site")
  @test.assert_eq(ws.abs("trees/a.alt").to_string(), "/repo/site/trees/a.alt")
  @test.assert_eq(
    ws.abs("/repo/site/trees/a.alt").to_string(),
    "/repo/site/trees/a.alt",
  )
  @test.assert_eq(ws.abs("trees\\a.alt").to_string(), "/repo/site/trees/a.alt")
  @test.assert_eq(ws.relative("/repo/site/trees/a.alt"), Some("trees/a.alt"))
  @test.assert_eq(ws.relative("/repo/site"), Some(""))
  @test.assert_eq(ws.relative("/other/a.alt"), None)
  @test.assert_eq(ws.contains("/repo/site/trees/a.alt"), true)
  @test.assert_eq(ws.contains("/other/a.alt"), false)
}

///|
test "empty workspace treats paths as already relative" {
  let ws = Workspace::new("")
  @test.assert_eq(ws.root().to_string(), "")
  @test.assert_eq(ws.abs("a/b.alt").to_string(), "a/b.alt")
  @test.assert_eq(ws.relative("a/b.alt"), Some("a/b.alt"))
}
