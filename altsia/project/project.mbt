///|
pub(all) struct ProjectConfig {
  sources : String
  preview_entry : String?
} derive(Eq, Debug)

///|
pub(all) struct ProjectLayout {
  root : String
  source_root : String
} derive(Eq, Debug)

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
  let sources_path : @path.Path = config.sources
  guard !sources_path.is_absolute() && !@model.is_absolute_path(config.sources) else {
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
pub fn ProjectLayout::new(
  root : String,
  config : ProjectConfig,
) -> ProjectLayout {
  { root: fs_normalize(root), source_root: source_root(root, config) }
}

///|
pub fn source_root(root : String, config : ProjectConfig) -> String {
  fs_join(root, config.sources)
}

///|
fn fs_normalize(path : String) -> String {
  let value : @path.Path = path
  value.normalize().to_string()
}

///|
fn fs_join(base : String, child : String) -> String {
  @path.Path::join(base, child).normalize().to_string()
}

///|
fn fs_is_absolute(path : String) -> Bool {
  let value : @path.Path = path
  value.is_absolute()
}

///|
pub fn should_skip_source_dir(name : String) -> Bool {
  name.has_prefix(".") || name.has_prefix("_")
}

///|
pub fn is_source_file(path : String) -> Bool {
  match @model.source_file_kind(path) {
    Some(_) => true
    None => false
  }
}

///|
pub fn source_relative_path(source_root : String, path : String) -> String? {
  let root = @model.normalize_path(fs_normalize(source_root))
  let value = @model.normalize_path(fs_normalize(path))
  let prefix = root + "/"
  if value.has_prefix(prefix) {
    Some(value.unsafe_substring(start=prefix.length(), end=value.length()))
  } else {
    None
  }
}

///|
pub fn resolve_entry_source_path(
  source_root : String,
  entry : String,
) -> Result[String, String] {
  let relative = if fs_is_absolute(entry) || @model.is_absolute_path(entry) {
    let full_path = fs_normalize(entry)
    match source_relative_path(source_root, full_path) {
      Some(value) => value
      None => return Err("entry is outside source root: " + entry)
    }
  } else {
    let value = @model.normalize_path(entry)
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
test "source discovery helpers are pure project rules" {
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
  let config = ProjectConfig::default()
  let layout = ProjectLayout::new("/repo/site", config)
  @test.assert_eq(@model.normalize_path(layout.source_root), "/repo/site/trees")
  match
    resolve_entry_source_path(layout.source_root, "/repo/site/trees/a/b.alt") {
    Ok(path) => @test.assert_eq(path, "a/b.alt")
    Err(error) => abort(error)
  }
  match resolve_entry_source_path(layout.source_root, "index.alt") {
    Ok(path) => @test.assert_eq(path, "index.alt")
    Err(error) => abort(error)
  }
}
