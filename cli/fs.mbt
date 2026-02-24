// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn read_input(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    @fs.IOError(msg) => {
      println(describe_io_error("reading", path, msg))
      None
    }
  }
}

///|
fn read_relative_input(input : String, path : String) -> String? {
  let input_dir = @path.Path::new(input).parent()
  let target_path = input_dir.join(@path.Path::new(path)).as_string()
  read_input(target_path)
}

///|
fn write_output(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    @fs.IOError(msg) => {
      println(describe_io_error("writing", path, msg))
      false
    }
  }
}

///|
fn default_output_path(
  input_path : String,
  origin_suffix~ : String,
  target_suffix~ : String,
) -> String {
  let end = input_path.length() - origin_suffix.length()
  let stem = input_path.unsafe_substring(start=0, end~)
  stem + target_suffix
}

///|
fn describe_io_error(action : String, path : String, msg : String) -> String {
  if msg.contains("No such file") ||
    msg.contains("cannot find") ||
    msg.contains("not found") {
    "I/O error while \{action}: file not found: \{path}"
  } else if msg.contains("Permission denied") ||
    msg.contains("Access is denied") ||
    msg.contains("access is denied") {
    "I/O error while \{action}: permission denied: \{path}"
  } else if msg.contains("Is a directory") || msg.contains("is a directory") {
    "I/O error while \{action}: expected a file path: \{path}"
  } else {
    "I/O error while \{action} \{path}: \{msg}"
  }
}
