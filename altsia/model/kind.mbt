///|
/// The kind of an altsia source file inside the workspace.
pub enum SourceFileKind {
  AltDocument
  AltLibrary
} derive(Eq, Debug)

///|
pub extend SourceFileKind with Eq::{not_equal, equal}

///|
pub extend SourceFileKind with Debug::{to_repr}

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
pub fn module_name_from_path(path : String) -> String {
  @vfs.Path::new(path)
  .basename()
  .strip_extension(".sia")
  .to_string()
  .replace_all(old=" ", new="_")
}

///|
test "source kinds follow workspace conventions" {
  @test.assert_eq(source_file_kind("index.alt"), Some(AltDocument))
  @test.assert_eq(source_file_kind("index.altsia"), Some(AltDocument))
  @test.assert_eq(source_file_kind("lib.sia"), Some(AltLibrary))
  @test.assert_eq(source_file_kind("README.md"), None)
  @test.assert_eq(module_name_from_path("a\\auto date.sia"), "auto_date")
}
