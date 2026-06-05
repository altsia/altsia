///|
pub fn find_project_root(start : String) -> ProjectRoot? {
  let mut current = @model.normalize_path(start)
  while true {
    let config_path = @model.join_path(current, "altsia.toml")
    if @fs.path_exists(config_path) {
      return Some({ root: current, config_path })
    }
    let parent = @model.dirname(current)
    if parent == current || parent == "" {
      return None
    }
    current = parent
  }
  None
}

///|
pub fn discover_project(start : String) -> Result[Project, String] {
  match find_project_root(start) {
    None => Err("missing altsia.toml from " + start)
    Some(config) => {
      let sources : Array[SourceFile] = []
      match collect_source_files(config.root, config.root, sources) {
        Ok(_) => Ok({ root: config.root, sources })
        Err(message) => Err(message)
      }
    }
  }
}

///|
fn collect_source_files(
  root : String,
  dir : String,
  sources : Array[SourceFile],
) -> Result[Unit, String] {
  let entries = @fs.read_dir(dir) catch {
    IOError(message) => return Err(message)
  }
  for entry in entries {
    let path = @model.join_path(dir, entry)
    let is_dir = @fs.is_dir(path) catch { IOError(_) => false }
    if is_dir {
      if entry != ".mooncakes" && entry != "_build" && entry != ".git" {
        match collect_source_files(root, path, sources) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    } else {
      match @model.source_file_kind(path) {
        Some(_) => {
          let source = @fs.read_file_to_string(path) catch {
            IOError(message) => return Err(message)
          }
          sources.push({
            path: @path.Path::relative(path, base=root).to_string(),
            source,
          })
        }
        None => ()
      }
    }
  }
  Ok(())
}
