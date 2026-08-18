///|
priv struct ProjectRoot {
  root : String
  config_path : String
}

///|
priv struct DiscoveredProject {
  project : @model.Project
  layout : @project.ProjectLayout
  config : @project.ProjectConfig
}

///|
priv suberror CliError {
  CliError(String)
} derive(Debug)

///|
fn main {
  let subcommands : Array[@argparse.Command] = [
    Command("preview", about="Compile an .alt project and print to stdout.", positionals=[
      PositionArg("entry", about="Path to the .alt entry file."),
    ]),
    Command("build", about="Compile an .alt project to an HTML file.", positionals=[
      PositionArg(
        "entry",
        about="Path to the .alt entry file.",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg("output", about="Path to the output HTML file."),
    ]),
  ]
  let command = @argparse.Command(
    "alt",
    about="The CLI tool for altsia.",
    subcommands~,
  )
  let matches = command.parse() catch { err => return println(err) }
  guard matches.subcommand is Some((name, sub)) else {
    return println(command.render_help())
  }
  match name {
    "preview" => run_preview(first_argument_value(sub.values, "entry"))
    "build" => {
      guard first_argument_value(sub.values, "entry") is Some(entry) else {
        return println(command.render_help())
      }
      run_build(entry, first_argument_value(sub.values, "output"))
    }
    _ => println(command.render_help())
  }
}

///|
fn first_argument_value(
  values : Map[String, Array[String]],
  name : String,
) -> String? {
  match values.get(name) {
    Some([value, ..]) => Some(value)
    _ => None
  }
}

///|
fn run_preview(entry : String?) -> Unit {
  try {
    let (project, entry_path) = load_project_for_entry(entry)
    println(compile_project_entry(project, entry_path))
  } catch {
    CliError(message) => println(message)
  }
}

///|
fn run_build(entry : String, output : String?) -> Unit {
  try {
    let (project, entry_path) = load_project_for_entry(Some(entry))
    let html = compile_project_entry(project, entry_path)
    let output_path = output.unwrap_or(default_output_path(entry))
    @fs.write_string_to_file(output_path, html) catch {
      IOError(message) =>
        println("I/O error while writing \{output_path}: \{message}")
    }
  } catch {
    CliError(message) => println(message)
  }
}

///|
fn compile_project_entry(
  project : @model.Project,
  entry_path : String,
) -> String raise CliError {
  @altsia.compile_alt_document(project.sources, entry_path) catch {
    error => raise CliError(error.render())
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
    discovered.layout.resolve_entry_source_path(entry_value) {
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
  let workspace = @vfs.Workspace::new(config.root)
  let layout = @project.ProjectLayout::new(workspace, project_config.sources)
  let sources : Array[@model.SourceFile] = []
  collect_source_files_into(layout.source_root, layout.source_root, sources)
  {
    project: @model.Project::new(config.root, sources),
    layout,
    config: project_config,
  }
}

///|
fn collect_source_files_into(
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
      guard !@project.should_skip_source_dir(entry) else { continue }
      collect_source_files_into(root, full_path, sources)
      continue
    }
    guard @project.is_source_file(full_path) else { continue }
    let source = @fs.read_file_to_string(full_path) catch {
      IOError(message) => raise CliError(message)
    }
    sources.push({
      path: @vfs.Path::new(full_path)
      .relative(base=@vfs.Path::new(root))
      .to_string(),
      source,
    })
  }
}

///|
fn default_output_path(entry : String) -> String {
  if entry.has_suffix(".alt") {
    entry.unsafe_substring(start=0, end=entry.length() - 4) + ".html"
  } else {
    entry + ".html"
  }
}
