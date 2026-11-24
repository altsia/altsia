///|
/// Emphasis syntax failures. Ranges are half-open UTF-8 byte offsets into
/// the original source, matching `Parser::next_event_range`.
#derive(Eq, Debug)
pub(all) suberror SyntaxError {
  InvalidEmphasisRun(Int32, Int32)
  MismatchedEmphasis(Int32, Int32)
  UnclosedEmphasis(Int32, Int32)
  NestedEmphasis(Int32, Int32)
}

///|
pub extend SyntaxError with Eq::{not_equal, equal}

///|
pub extend SyntaxError with Debug::{to_repr}

///|
pub extend SyntaxError with Show::{to_string, output}

///|
pub impl Show for SyntaxError with fn output(self, logger) {
  let (start, end, reason) = match self {
    InvalidEmphasisRun(start, end) =>
      (start, end, "emphasis delimiter runs must have length one or two")
    MismatchedEmphasis(start, end) =>
      (start, end, "emphasis delimiters must match without nesting")
    UnclosedEmphasis(start, end) => (start, end, "unclosed emphasis delimiter")
    NestedEmphasis(start, end) => (start, end, "emphasis cannot nest")
  }
  logger.write_string("syntax error at bytes \{start}..\{end}: \{reason}")
}
