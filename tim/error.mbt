///|
fn describe_io_error(action : String, path : String, msg : String) -> String {
  match () {
    _ if is_file_not_found_error(msg) =>
      "I/O error while \{action}: file not found: \{path}"
    _ if is_permission_error(msg) =>
      "I/O error while \{action}: permission denied: \{path}"
    _ if is_directory_error(msg) =>
      "I/O error while \{action}: expected a file path: \{path}"
    _ => "I/O error while \{action} \{path}: \{msg}"
  }
}

///|
fn is_file_not_found_error(msg : String) -> Bool {
  msg.contains("No such file") ||
  msg.contains("cannot find") ||
  msg.contains("not found")
}

///|
fn is_permission_error(msg : String) -> Bool {
  msg.contains("Permission denied") ||
  msg.contains("Access is denied") ||
  msg.contains("access is denied")
}

///|
fn is_directory_error(msg : String) -> Bool {
  msg.contains("Is a directory") || msg.contains("is a directory")
}
