///|
fn usage() -> Unit {
  let text =
    $|alt 0.1.0
    $|
    $|USAGE:
    $|  alt preview
    $|  alt preview <entry.alt>
    $|  alt build <entry.alt> [output.html]
    $|  alt --help
    $|
    $|The project root is the nearest ancestor directory containing altsia.toml.
    $|
  println(text)
}

///|
priv struct ProjectRoot {
  root : String
  config_path : String
}

///|
priv struct DiscoveredProject {
  project : @model.Project
  source_root : String
  config : @project.ProjectConfig
}

///|
priv suberror CliError {
  CliError(String)
} derive(Debug)

///|
fn main {
  match @env.args() {
    [_] | [_, "-h"] | [_, "--help"] | [_, "help"] => usage()
    [_, "preview"] => run_preview(None)
    [_, "preview", entry] => run_preview(Some(entry))
    [_, "build", entry] => run_build(entry, None)
    [_, "build", entry, output] => run_build(entry, Some(output))
    [_, command, ..] => println("unknown command: " + command)
    [] => usage()
  }
}

///|
fn run_preview(entry : String?) -> Unit {
  try load_project_for_entry(entry) catch {
    CliError(message) => println(message)
  } noraise {
    result => {
      let (project, entry_path) = result
      try @altsia.compile_alt_document(project.sources, entry_path) catch {
        error => println(error.render())
      } noraise {
        html => println(html)
      }
    }
  }
}

///|
fn run_build(entry : String, output : String?) -> Unit {
  try load_project_for_entry(Some(entry)) catch {
    CliError(message) => println(message)
  } noraise {
    result => {
      let (project, entry_path) = result
      try @altsia.compile_alt_document(project.sources, entry_path) catch {
        error => println(error.render())
      } noraise {
        html => {
          let output_path = output.unwrap_or(default_output_path(entry))
          @fs.write_string_to_file(output_path, html) catch {
            IOError(message) =>
              println("I/O error while writing \{output_path}: \{message}")
          }
        }
      }
    }
  }
}

///|
fn load_project_for_entry(
  entry : String?,
) -> (@model.Project, String) raise CliError {
  let start = match entry {
    Some(entry) => {
      let entry_path : @path.Path = entry
      @path.Path::dirname(entry_path.resolve()).to_string()
    }
    None => {
      let current : @path.Path = "."
      current.resolve().to_string()
    }
  }
  let discovered = discover_project(start)
  let entry_value = match entry {
    Some(entry) => {
      let entry_path : @path.Path = entry
      entry_path.resolve().to_string()
    }
    None =>
      match discovered.config.preview_entry {
        Some(entry) => entry
        None => raise CliError("missing [preview].entry in altsia.toml")
      }
  }
  let entry_source_path = match
    @project.resolve_entry_source_path(discovered.source_root, entry_value) {
    Ok(value) => value
    Err(message) => raise CliError(message)
  }
  (discovered.project, entry_source_path)
}

///|
fn find_project_root(start : String) -> ProjectRoot? {
  let start_path : @path.Path = start
  let mut current = start_path.normalize().to_string()
  while true {
    let config_path = @path.Path::join(current, @project.config_file_name())
      .normalize()
      .to_string()
    if @fs.path_exists(config_path) {
      return Some({ root: current, config_path })
    }
    let current_path : @path.Path = current
    let parent = current_path.dirname().to_string()
    if parent == current || parent == "" {
      return None
    }
    current = parent
  }
  None
}

///|
fn discover_project(start : String) -> DiscoveredProject raise CliError {
  guard find_project_root(start) is Some(config) else {
    raise CliError("missing altsia.toml from " + start)
  }
  let config_source = @fs.read_file_to_string(config.config_path) catch {
    IOError(message) => raise CliError(message)
  }
  let project_config = match @project.parse_project_config(config_source) {
    Ok(value) => value
    Err(message) => raise CliError(message)
  }
  let source_root = @project.source_root(config.root, project_config)
  let sources : Array[@model.SourceFile] = []
  collect_source_files(source_root, source_root, sources)
  {
    project: { root: source_root, sources },
    source_root,
    config: project_config,
  }
}

///|
fn collect_source_files(
  root : String,
  dir : String,
  sources : Array[@model.SourceFile],
) -> Unit raise CliError {
  let entries = @fs.read_dir(dir) catch {
    IOError(message) => raise CliError(message)
  }
  for entry in entries {
    let full_path = @path.Path::join(dir, entry).normalize().to_string()
    let is_dir = @fs.is_dir(full_path) catch { IOError(_) => false }
    if is_dir {
      if !@project.should_skip_source_dir(entry) {
        collect_source_files(root, full_path, sources)
      }
    } else if @project.is_source_file(full_path) {
      let source = @fs.read_file_to_string(full_path) catch {
        IOError(message) => raise CliError(message)
      }
      sources.push({
        path: @model.normalize_path(
          @path.Path::relative(full_path, base=root).to_string(),
        ),
        source,
      })
    }
  }
}

///|
fn default_output_path(entry : String) -> String {
  if entry.length() >= 4 &&
    entry.unsafe_substring(start=entry.length() - 4, end=entry.length()) ==
    ".alt" {
    entry.unsafe_substring(start=0, end=entry.length() - 4) + ".html"
  } else {
    entry + ".html"
  }
}
