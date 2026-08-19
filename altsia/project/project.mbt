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
  let normalized = @vfs.Path::new(entry).normalize().to_string()
  let relative = if @vfs.Path::new(entry).is_absolute() {
    match self.source_relative_path(normalized) {
      Some(value) => value
      None => return Err("entry is outside source root: " + entry)
    }
  } else {
    guard normalized != ".." && !normalized.has_prefix("../") else {
      return Err("entry is outside source root: " + entry)
    }
    normalized
  }
  match @model.source_file_kind(relative) {
    Some(AltDocument) => Ok(relative)
    _ => Err("preview entry must be an .alt or .altsia file: " + relative)
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
priv suberror ConfigError {
  ConfigError(String)
}

///|
pub fn parse_project_config(source : String) -> Result[ProjectConfig, String] {
  Ok(parse_project_config_internal(source)) catch {
    ConfigError(message) => Err(message)
  }
}

///|
fn parse_project_config_internal(
  source : String,
) -> ProjectConfig raise ConfigError {
  let value = @toml.parse(source) catch {
    error =>
      raise ConfigError("failed to parse altsia.toml: " + error.to_string())
  }
  match value {
    TomlTable(table) => project_config_from_table(table)
    value =>
      raise ConfigError(
        "altsia.toml root must be a table, got " + value.type_name(),
      )
  }
}

///|
fn project_config_from_table(
  table : Map[String, @toml.TomlValue],
) -> ProjectConfig raise ConfigError {
  let mut config = ProjectConfig::default()
  if table.get("altsia") is Some(value) {
    guard value is TomlTable(altsia) else {
      raise ConfigError("[altsia] must be a table, got " + value.type_name())
    }
    let sources = optional_string(altsia, "sources", "[altsia].sources")
    if sources is Some(sources) {
      config = { ..config, sources, }
    }
  }
  if table.get("preview") is Some(value) {
    guard value is TomlTable(preview) else {
      raise ConfigError("[preview] must be a table, got " + value.type_name())
    }
    let entry = optional_string(preview, "entry", "[preview].entry")
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
) -> String? raise ConfigError {
  match table.get(key) {
    Some(TomlString(value)) => Some(value)
    Some(value) =>
      raise ConfigError("\{label} must be a string, got \{value.type_name()}")
    None => None
  }
}

///|
fn validate_project_config(
  config : ProjectConfig,
) -> ProjectConfig raise ConfigError {
  guard config.sources.trim() != "" else {
    raise ConfigError("[altsia].sources must not be empty")
  }
  guard !@vfs.Path::new(config.sources).is_absolute() else {
    raise ConfigError("[altsia].sources must be relative to the project root")
  }
  guard config.preview_entry.map_or(true, entry => entry.trim() != "") else {
    raise ConfigError("[preview].entry must not be empty")
  }
  config
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
