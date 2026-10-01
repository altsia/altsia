///|
/// Number of lines included when `--range` gives only a start line.
let default_range_span = 42

///|
/// Errors raised when parsing a `--range` value.
suberror RangeError {
  Malformed
  NotALineNumber(String)
  EndBeforeStart
}

///|
/// Renders each `RangeError` variant as a user-facing message.
impl Show for RangeError with fn output(self, logger) {
  match self {
    Malformed => logger.write_string("expected the form N or N,M")
    NotALineNumber(component) =>
      logger.write_string("\{component} is not a valid line number")
    EndBeforeStart => logger.write_string("expected 1 <= start <= end")
  }
}

///|
/// Parses a 1-indexed line number, rejecting anything that is not a
/// positive integer.
fn parse_line_number(text : String) -> Int raise RangeError {
  let number = @string.parse_int(text) catch {
    _ => raise RangeError::NotALineNumber(text)
  }
  guard number > 0 else { raise RangeError::NotALineNumber(text) }
  number
}

///|
/// Parses `--range` values of the form `N` or `N,M`, where lines are
/// 1-indexed and the end is inclusive. A single `N` spans `N` up to
/// `N + default_range_span`.
fn parse_range(value : String) -> (Int, Int) raise RangeError {
  let parts = value.split(",").map(part => part.trim().to_owned()).to_array()
  match parts {
    [start_str, end_str] => {
      let start = parse_line_number(start_str)
      let end = parse_line_number(end_str)
      guard end >= start else { raise RangeError::EndBeforeStart }
      (start, end)
    }
    [start_str] => {
      let start = parse_line_number(start_str)
      (start, start + default_range_span)
    }
    _ => raise RangeError::Malformed
  }
}

///|
/// Extracts the 1-indexed, inclusive line range [start, end] from `content`.
/// Lines outside the range are not materialized. A trailing newline yields
/// an empty element after the last line; drop it so the range matches what a
/// text editor shows.
fn extract_range(content : String, start : Int, end : Int) -> Array[String] {
  let lines = content
    .split("\n")
    .drop(start - 1)
    .take(end - start + 1)
    .map(line => line.to_owned())
    .to_array()
  if content.has_suffix("\n") && lines.last() is Some("") {
    ignore(lines.pop())
  }
  lines
}
