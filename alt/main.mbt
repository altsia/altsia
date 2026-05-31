///|
fn usage() -> Unit {
  let text =
    $|alt 0.1.0
    $|
    $|USAGE:
    $|  alt preview <entry.alt>
    $|  alt build <entry.alt> [output.html]
    $|  alt --help
    $|
    $|The project root is the nearest ancestor directory containing altsia.toml.
    $|
  println(text)
}

///|
fn main {
  match @env.args() {
    [_] | [_, "-h"] | [_, "--help"] | [_, "help"] => usage()
    [_, "preview", entry] => run_preview(entry)
    [_, "build", entry] => run_build(entry, None)
    [_, "build", entry, output] => run_build(entry, Some(output))
    [_, command, ..] => println("unknown command: " + command)
    [] => usage()
  }
}

///|
fn run_preview(entry : String) -> Unit {
  match load_project_for_entry(entry) {
    Err(message) => println(message)
    Ok((project, entry_path)) =>
      match @altsia.compile_alt_document(project.sources, entry_path) {
        Ok(html) => println(html)
        Err(error) => println(error.render())
      }
  }
}

///|
fn run_build(entry : String, output : String?) -> Unit {
  match load_project_for_entry(entry) {
    Err(message) => println(message)
    Ok((project, entry_path)) =>
      match @altsia.compile_alt_document(project.sources, entry_path) {
        Err(error) => println(error.render())
        Ok(html) => {
          let output_path = output.unwrap_or(default_output_path(entry))
          @fs.write_string_to_file(output_path, html) catch {
            IOError(message) =>
              println("I/O error while writing " + output_path + ": " + message)
          }
        }
      }
  }
}

///|
fn load_project_for_entry(
  entry : String,
) -> Result[(@altsia.Project, String), String] {
  let start = @path.Path::dirname(entry).to_string()
  match @altsia.discover_project(start) {
    Err(message) => Err(message)
    Ok(project) => {
      let entry_path : @path.Path = entry
      let relative_entry = entry_path
        .normalize()
        .relative(base=project.root)
        .to_string()
      Ok((project, relative_entry))
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
