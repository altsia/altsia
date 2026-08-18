///|
pub(all) struct ProjectConfig {
  sources : String
  preview_entry : String?
} derive(Eq, Debug)

///|
/// The layout of an altsia workspace: the workspace root plus the
/// absolute source directory that holds all `.alt`/`.altsia`/`.sia`
/// files.
pub struct ProjectLayout {
  workspace : @vfs.Workspace
  source_root : String
} derive(Eq, Debug)

///|
pub fn ProjectLayout::new(
  workspace : @vfs.Workspace,
  sources_dir : String,
) -> ProjectLayout {
  { workspace, source_root: workspace.abs(sources_dir).to_string() }
}

///|
pub fn ProjectLayout::source_relative_path(
  self : ProjectLayout,
  path : String,
) -> String? {
  let root = @vfs.Path::new(self.source_root).normalize().to_string()
  let value = @vfs.Path::new(path).normalize().to_string()
  let prefix = root + "/"
  if value == root {
    Some("")
  } else if value.has_prefix(prefix) {
    Some(value.unsafe_substring(start=prefix.length(), end=value.length()))
  } else {
    None
  }
}

///|
pub fn ProjectLayout::resolve_entry_source_path(
  self : ProjectLayout,
  entry : String,
) -> Result[String, String] {
  let relative = if @vfs.Path::new(entry).is_absolute() {
    let full_path = @vfs.Path::new(entry).normalize().to_string()
    match self.source_relative_path(full_path) {
      Some(value) => value
      None => return Err("entry is outside source root: " + entry)
    }
  } else {
    let value = @vfs.Path::new(entry).normalize().to_string()
    if value == ".." || value.has_prefix("../") {
      return Err("entry is outside source root: " + entry)
    }
    value
  }
  match @model.source_file_kind(relative) {
    Some(AltDocument) => Ok(relative)
    Some(AltLibrary) =>
      Err("preview entry must be an .alt or .altsia file: " + relative)
    None => Err("preview entry must be an .alt or .altsia file: " + relative)
  }
}

///|
pub fn should_skip_source_dir(name : String) -> Bool {
  name.has_prefix(".") || name.has_prefix("_")
}

///|
pub fn is_source_file(path : String) -> Bool {
  @model.source_file_kind(path) is Some(_)
}

///|
pub fn config_file_name() -> String {
  "altsia.toml"
}

///|
pub fn ProjectConfig::default() -> ProjectConfig {
  { sources: "trees", preview_entry: Some("index.alt") }
}

///|
pub fn parse_project_config(source : String) -> Result[ProjectConfig, String] {
  let value = try @toml.parse(source) catch {
    error => return Err("failed to parse altsia.toml: " + error.to_string())
  } noraise {
    value => value
  }
  match value {
    TomlTable(table) => project_config_from_table(table)
    value => Err("altsia.toml root must be a table, got " + value.type_name())
  }
}

///|
fn project_config_from_table(
  table : Map[String, @toml.TomlValue],
) -> Result[ProjectConfig, String] {
  let mut config = ProjectConfig::default()
  if table.get("altsia") is Some(value) {
    guard value is TomlTable(altsia) else {
      return Err("[altsia] must be a table, got " + value.type_name())
    }
    let sources = match optional_string(altsia, "sources", "[altsia].sources") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if sources is Some(sources) {
      config = { ..config, sources, }
    }
  }
  if table.get("preview") is Some(value) {
    guard value is TomlTable(preview) else {
      return Err("[preview] must be a table, got " + value.type_name())
    }
    let entry = match optional_string(preview, "entry", "[preview].entry") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if entry is Some(entry) {
      config = { ..config, preview_entry: Some(entry) }
    }
  }
  validate_project_config(config)
}

///|
fn optional_string(
  table : Map[String, @toml.TomlValue],
  key : String,
  label : String,
) -> Result[String?, String] {
  match table.get(key) {
    Some(TomlString(value)) => Ok(Some(value))
    Some(value) => Err("\{label} must be a string, got \{value.type_name()}")
    None => Ok(None)
  }
}

///|
fn validate_project_config(
  config : ProjectConfig,
) -> Result[ProjectConfig, String] {
  guard config.sources.trim() != "" else {
    return Err("[altsia].sources must not be empty")
  }
  guard !@vfs.Path::new(config.sources).is_absolute() else {
    return Err("[altsia].sources must be relative to the project root")
  }
  match config.preview_entry {
    Some(entry) if entry.trim() == "" =>
      return Err("[preview].entry must not be empty")
    _ => ()
  }
  Ok(config)
}

///|
test "empty config uses kodama-style defaults" {
  match parse_project_config("") {
    Ok(config) =>
      @test.assert_eq(config, {
        sources: "trees",
        preview_entry: Some("index.alt"),
      })
    Err(error) => abort(error)
  }
}

///|
test "parses source root and preview entry" {
  match
    parse_project_config(
      (
        #|[altsia]
        #|sources = "notes"
        #|
        #|[preview]
        #|entry = "start.altsia"
        #|
      ),
    ) {
    Ok(config) =>
      @test.assert_eq(config, {
        sources: "notes",
        preview_entry: Some("start.altsia"),
      })
    Err(error) => abort(error)
  }
}

///|
test "rejects absolute source root" {
  match parse_project_config("[altsia]\nsources = \"/abs/trees\"") {
    Err(message) =>
      @test.assert_eq(message.has_prefix("[altsia].sources"), true)
    Ok(_) => abort("expected error")
  }
}

///|
test "source discovery helpers are pure workspace rules" {
  @test.assert_eq(should_skip_source_dir(".drafts"), true)
  @test.assert_eq(should_skip_source_dir("_build"), true)
  @test.assert_eq(should_skip_source_dir("chapters"), false)
  @test.assert_eq(is_source_file("index.alt"), true)
  @test.assert_eq(is_source_file("index.altsia"), true)
  @test.assert_eq(is_source_file("lib.sia"), true)
  @test.assert_eq(is_source_file("README.md"), false)
}

///|
test "entry is normalized relative to source root" {
  let workspace = @vfs.Workspace::new("/repo/site")
  let layout = ProjectLayout::new(workspace, "trees")
  @test.assert_eq(layout.source_root, "/repo/site/trees")
  @test.assert_eq(
    layout.source_relative_path("/repo/site/trees/a/b.alt"),
    Some("a/b.alt"),
  )
  @test.assert_eq(layout.source_relative_path("/other/a.alt"), None)
  match layout.resolve_entry_source_path("/repo/site/trees/a/b.alt") {
    Ok(path) => @test.assert_eq(path, "a/b.alt")
    Err(error) => abort(error)
  }
  match layout.resolve_entry_source_path("index.alt") {
    Ok(path) => @test.assert_eq(path, "index.alt")
    Err(error) => abort(error)
  }
  match layout.resolve_entry_source_path("lib.sia") {
    Err(message) => @test.assert_eq(message.has_prefix("preview entry"), true)
    Ok(_) => abort("expected error")
  }
  match layout.resolve_entry_source_path("../outside.alt") {
    Err(message) =>
      @test.assert_eq(message.has_prefix("entry is outside"), true)
    Ok(_) => abort("expected error")
  }
}
