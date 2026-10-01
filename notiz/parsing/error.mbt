///|
/// Structured syntax errors for the notiz markdown parser.
///
/// The parser engine (`talcparsec`) reports failures as string labels.
/// [`SyntaxError::of_parse_error`] converts those labels into the typed
/// [`Expected`] vocabulary once, at the package boundary, so error handling
/// below never matches on raw strings.

///|
/// What the parser expected to find at a failure position.
pub(all) enum Expected {
  /// A specific character, e.g. `'*'` from the `char` combinator.
  Char(Char)
  /// A specific literal, e.g. `"```"` from the `string` combinator.
  Str(String)
  /// Any character of a set, e.g. the inline special characters.
  OneOf(String)
  /// The parser ran out of input.
  EndOfInput
  /// The `| --- | --- |` row that must follow a table header row.
  TableDelimiterRow
  /// A `key: value` line of a frontmatter block.
  FrontmatterEntry
  /// The non-empty value after the `:` of a frontmatter entry.
  FrontmatterValue
  /// A paper size name, e.g. `a4`, for the frontmatter `paper` attribute.
  PaperSize(String)
  /// Any other parser label, e.g. `"not newline"`.
  Other(String)
} derive(Eq, Debug)

///|
pub extend Expected with Eq::{not_equal, equal}

///|
pub extend Expected with Debug::{to_repr}

///|
/// A syntax error raised while parsing notiz markdown.
///
/// Carries the failure [`position`](`SyntaxError::position`) and a structured
/// description of what went wrong, instead of an opaque message string.
pub(all) suberror SyntaxError {
  /// At the position, the input did not match any of the expected items.
  Mismatch(@talc.Position, Array[Expected])
  /// At the position, the forbidden construct was found.
  Unexpected(@talc.Position, String)
} derive(Eq, Debug)

///|
pub extend SyntaxError with Eq::{not_equal, equal}

///|
pub extend SyntaxError with Debug::{to_repr}

///|
/// The source position where the parse failed.
pub fn SyntaxError::position(self : SyntaxError) -> @talc.Position {
  match self {
    Mismatch(position, _) | Unexpected(position, _) => position
  }
}

///|
/// Converts a `@talc.ParseError` into the typed [`SyntaxError`].
///
/// This is the single place that interprets the parser engine's string
/// labels; every label below this point is structured.
pub fn SyntaxError::of_parse_error(err : @talc.ParseError) -> SyntaxError {
  let position = @talc.Position::{
    offset: err.offset(),
    line: err.line(),
    column: err.column(),
  }
  let message = err.message_text()
  match () {
    _ if message.has_prefix("unexpected ") =>
      SyntaxError::Unexpected(position, message.exact_view(start=11).to_owned())
    _ if message.has_prefix("expected ") =>
      SyntaxError::Mismatch(position, [
        classify_expected(message.exact_view(start=9).to_owned()),
      ])
    _ if !message.is_empty() =>
      SyntaxError::Mismatch(position, [Expected::Other(message)])
    _ => SyntaxError::Mismatch(position, err.expected().map(classify_expected))
  }
}

///|
/// One-line summary, e.g. `parse error at 1:2: expected a space`.
///
/// The full report with the source snippet, caret, and found token is
/// [`format_parse_error`], which needs the source text.
pub impl Show for SyntaxError with fn output(self, logger) {
  let position = self.position()
  let detail = match self {
    Mismatch(_, expected) => "expected \{describe_all(expected)}"
    Unexpected(_, token) => "unexpected \{token}"
  }
  logger.write_string(
    "parse error at \{position.line}:\{position.column}: \{detail}",
  )
}

///|
pub extend SyntaxError with Show::{to_string, output}

///|
/// Formats a syntax error with a source snippet and caret marker.
///
/// Returns a multi-line message like:
///
/// ```text
/// parse error at 1:2: expected a space, found 'a'
///
///  1 |   hello world
///    |   ^
/// ```
pub fn format_parse_error(err : SyntaxError, source : String) -> String {
  let position = err.position()
  let detail = error_detail(err, source)
  let lines = source.split("\n").to_array()
  let source_line = {
    guard position.line >= 1 && position.line <= lines.length() else { "" }
    lines[position.line - 1].to_owned()
  }
  let label = position.line.to_string()
  let gutter = " ".repeat(label.length())
  let sb = StringBuilder()
  sb <+ "parse error at \{position.line}:\{position.column}: \{detail}"
  if !source_line.is_empty() {
    sb.write_string("\n\n")
    sb <+ "\{gutter} |"
    sb.write_string("\n")
    sb <+ "\{label} | \{source_line}"
    sb.write_string("\n")
    sb <+ "\{gutter} | \{caret_marker(source_line, position.column)}"
  }
  sb.to_string()
}

///|
fn error_detail(err : SyntaxError, source : String) -> String {
  let position = err.position()
  match err {
    Mismatch(_, expected) if expected.is_empty() => "syntax error"
    Mismatch(_, expected) =>
      "expected \{describe_all(expected)}, found \{found_token(source, position.offset)}"
    Unexpected(_, token) => "unexpected \{token}"
  }
}

///|
fn classify_expected(label : String) -> Expected {
  if is_quoted(label, '\'') {
    Expected::Char(label.get_char(label.length() - 2).unwrap())
  } else if is_quoted(label, '"') {
    Expected::Str(label.exact_view(start=1, end=label.length() - 1).to_owned())
  } else if label.has_prefix("one of ") {
    Expected::OneOf(label.exact_view(start=7).to_owned())
  } else {
    match label {
      "end of input" => Expected::EndOfInput
      "table delimiter row" => Expected::TableDelimiterRow
      "a frontmatter entry such as key: value" => Expected::FrontmatterEntry
      "a frontmatter value" => Expected::FrontmatterValue
      label if label.has_prefix("a paper size such as ") =>
        Expected::PaperSize(label.exact_view(start=21).to_owned())
      _ => Expected::Other(label)
    }
  }
}

///|
/// True when `label` is a quoted literal: starts and ends with `quote`.
fn is_quoted(label : String, quote : Char) -> Bool {
  label.length() >= 2 &&
  label.get_char(0) == Some(quote) &&
  label.get_char(label.length() - 1) == Some(quote)
}

///|
/// Human-readable phrasing of an expected item.
fn describe(expected : Expected) -> String {
  match expected {
    Char(' ') => "a space"
    Char('\n') => "a newline"
    Char(c) => "'\{c}'"
    Str(s) => "\"\{s}\""
    OneOf(s) => "one of \{s}"
    EndOfInput => "end of input"
    TableDelimiterRow => "a table delimiter row such as | --- | --- |"
    FrontmatterEntry => "a frontmatter entry such as key: value"
    FrontmatterValue => "a frontmatter value"
    PaperSize(names) => "a paper size such as \{names}"
    Other(s) => s
  }
}

///|
fn describe_all(expected : Array[Expected]) -> String {
  expected.map(describe).join(" or ")
}

///|
/// What the parser actually encountered at the failure offset.
fn found_token(source : String, offset : Int) -> String {
  source
  .get_char(offset)
  .map_or("end of input", c => {
    match c {
      '\n' => "a newline"
      ' ' => "a space"
      _ => "'\{c}'"
    }
  })
}

///|
/// One space per column before the error, then `^`.
fn caret_marker(line : String, col : Int) -> String {
  " ".repeat((col - 1).min(line.length())) + "^"
}
