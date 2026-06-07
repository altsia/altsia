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
  let parsed = try? @toml.parse(source)
  let value = match parsed {
    Ok(value) => value
    Err(error) =>
      return Err("failed to parse altsia.toml: " + error.to_string())
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
  match table.get("altsia") {
    Some(TomlTable(altsia)) =>
      match optional_string(altsia, "sources", "[altsia].sources") {
        Ok(Some(sources)) => config = { ..config, sources, }
        Ok(None) => ()
        Err(error) => return Err(error)
      }
    Some(value) =>
      return Err("[altsia] must be a table, got " + value.type_name())
    None => ()
  }
  match table.get("preview") {
    Some(TomlTable(preview)) =>
      match optional_string(preview, "entry", "[preview].entry") {
        Ok(Some(entry)) => config = { ..config, preview_entry: Some(entry) }
        Ok(None) => ()
        Err(error) => return Err(error)
      }
    Some(value) =>
      return Err("[preview] must be a table, got " + value.type_name())
    None => ()
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
    Some(value) => Err(label + " must be a string, got " + value.type_name())
    None => Ok(None)
  }
}

///|
fn validate_project_config(
  config : ProjectConfig,
) -> Result[ProjectConfig, String] {
  if config.sources.trim() == "" {
    return Err("[altsia].sources must not be empty")
  }
  if @model.is_absolute_path(config.sources) {
    return Err("[altsia].sources must be relative to the project root")
  }
  match config.preview_entry {
    Some(entry) =>
      if entry.trim() == "" {
        return Err("[preview].entry must not be empty")
      }
    None => ()
  }
  Ok(config)
}

///|
pub fn ProjectLayout::new(
  root : String,
  config : ProjectConfig,
) -> ProjectLayout {
  { root: @model.normalize_path(root), source_root: source_root(root, config) }
}

///|
pub fn source_root(root : String, config : ProjectConfig) -> String {
  @model.join_path(root, config.sources)
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
  let root = @model.normalize_path(source_root)
  let value = @model.normalize_path(path)
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
  let full_path = if @model.is_absolute_path(entry) {
    @model.normalize_path(entry)
  } else {
    @model.join_path(source_root, entry)
  }
  let relative = match source_relative_path(source_root, full_path) {
    Some(value) => value
    None => return Err("entry is outside source root: " + entry)
  }
  match @model.source_file_kind(relative) {
    Some(Alt) => Ok(relative)
    Some(Sia) =>
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
  @test.assert_eq(layout.source_root, "/repo/site/trees")
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
