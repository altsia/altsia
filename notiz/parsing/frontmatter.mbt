///|
/// YAML-lite frontmatter: a metadata block at the very start of a document,
/// delimited by `---` lines.
///
/// The opener line is exactly `---` (optional trailing whitespace). Body
/// lines are either blank (skipped) or single-line `key: value` entries:
/// `key` is any string without whitespace or `:` (leading whitespace is
/// trimmed), `value` is the rest of the line, trimmed, and may itself
/// contain `:`. An empty value is an error. Duplicate keys overwrite,
/// keeping the first insertion position; the core linked hash map preserves
/// insertion order. `---\n---` is an empty frontmatter.
///
/// The opener commits: a body line that is not a valid entry (or a missing
/// closing `---`) is a hard syntax error, never a fallback to thematic
/// break. A `---` line followed immediately by end of input stays a
/// thematic break.
///
/// Keys are classified at parse time: keys with a fixed builtin meaning
/// (`lang`) are stored as fields of [`Builtin`], everything else goes to
/// [`Frontmatter::custom`]. Key comparison is case-sensitive, so `Lang` is
/// a custom key.

///|
/// The builtin frontmatter attributes. Every field has a stable value:
/// attributes not present in the source keep their default, so backends
/// read plain strings instead of options.
pub(all) struct Builtin {
  /// The document language tag; defaults to `"en"`.
  lang : String
  /// The paper size of the document; defaults to A4.
  paper : Paper
  /// The document title; empty when absent.
  title : String
} derive(Eq, Debug)

///|
pub extend Builtin with Eq::{not_equal, equal}

///|
pub extend Builtin with Debug::{to_repr}

///|
/// A parsed frontmatter block, split into builtin attributes and
/// user-defined data.
pub(all) struct Frontmatter {
  /// Attributes with a special meaning to backends.
  builtin : Builtin
  /// Keys not recognized as builtin attributes.
  custom : Map[String, String]
}

///|
/// The default builtin attributes, used when no frontmatter is present.
let default_builtin : Builtin = { lang: "en", paper: A4, title: "", }

///|
/// The default frontmatter, used when a document has no frontmatter block:
/// a missing frontmatter is equivalent to an empty one.
let default_frontmatter : Frontmatter = {
  builtin: default_builtin,
  custom: Map([]),
}

///|
/// The frontmatter equivalent to a missing one: default builtin attributes
/// and no custom data.
pub fn Frontmatter::default() -> Frontmatter {
  default_frontmatter
}

///|
/// Non-newline whitespace, matching `blank_line`'s convention.
let fm_ws_no_nl : @talc.CParser = @talc.satisfy("non-newline whitespace", c => {
  c.is_whitespace() && c != '\n'
})

///|
/// A line ending, or end of input.
let fm_line_end : @talc.StringParser[Unit] = fm_ws_no_nl
  .many()
  .skip(@talc.newline)
  .map(_ => ())
  .attempt()
  .or(@talc.eof())

///|
/// The opener `---` line, followed by at least one more line: a lone
/// `---` at end of input is a thematic break, not a frontmatter.
///
/// The trailing `.attempt()` is what lets `----`, `---x`, and a lone `---`
/// fall through to the regular block parsers.
let fm_opener : @talc.StringParser[Unit] = @talc.string("---")
  .then(fm_line_end)
  .then(@talc.eof().not_followed_by("end of input"))
  .map(_ => ())
  .attempt()

///|
/// The closing `---` line. Exactly three dashes: `----` never closes.
let fm_closer : @talc.StringParser[Unit] = @talc.string("---")
  .then(fm_line_end)
  .map(_ => ())

///|
/// Zero-width lookahead for the closing line: lets `many_until` stop at
/// the first `---` without consuming it.
let fm_closer_peek : @talc.StringParser[Unit] = @talc.Parser::new(input => {
  match fm_closer.run(input) {
    Ok(_) => Ok(((), input))
    Err(_) => Err(@talc.ParseError::message(input, "\"---\""))
  }
})

///|
/// A key character: anything but whitespace, `\n`, or `:`.
let fm_key_char : @talc.CParser = @talc.satisfy("a frontmatter key character", c => {
  c != ':' && c != '\n' && !c.is_whitespace()
})

///|
/// One `key: value` entry: optional leading whitespace, a key, `:`, then
/// the rest of the line as the value. The value must be non-empty, and a
/// `paper` value must name a known paper size.
let fm_entry_raw : @talc.StringParser[(String, String)] = @talc.Parser::new(input => {
  let key_result = fm_ws_no_nl
    .many()
    .then(@talc.many_chars1(fm_key_char))
    .skip(@talc.char(':'))
    .run(input)
  match key_result {
    Err(error) => Err(error)
    Ok((key, rest)) => {
      let value_result = @talc.line_content
        .bind(value => @talc.newline.map(_ => value.trim().to_owned()))
        .run(rest)
      match value_result {
        Err(error) => Err(error)
        Ok((value, after)) =>
          if value.is_empty() {
            Err(
              @talc.ParseError::message(input, "expected a frontmatter value").with_commit(),
            )
          } else if key == "paper" && Paper::from_string(value) is Err(_) {
            Err(
              @talc.ParseError::message(
                input,
                "expected a paper size such as \{Paper::names().join(" or ")}",
              ).with_commit(),
            )
          } else {
            Ok(((key, value), after))
          }
      }
    }
  }
})

///|
/// The entry parser with a single clear failure label: any body line that
/// consumed input while failing is reported as a missing entry, at the
/// line start. A failure that consumed nothing (e.g. end of input) is
/// passed through, so the missing closing `---` is reported instead.
let fm_entry : @talc.StringParser[(String, String)] = @talc.Parser::new(input => {
  match fm_entry_raw.run(input) {
    Ok(result) => Ok(result)
    Err(error) =>
      if error.offset() == input.cursor() {
        Err(error)
      } else {
        Err(
          @talc.ParseError::message(
            input, "expected a frontmatter entry such as key: value",
          ).with_commit(),
        )
      }
  }
})

///|
/// A body line: a blank line (skipped) or an entry.
let fm_body_item : @talc.StringParser[(String, String)?] = @talc.choice([
  blank_line.map(_ => None),
  fm_entry.map(entry => Some(entry)),
])

///|
/// The frontmatter body: entries until the first closing `---`.
let fm_body : @talc.StringParser[Array[(String, String)]] = fm_body_item
  .many_until(fm_closer_peek)
  .map(items => items.filter_map(x => x))

///|
/// Classifies the entries into the builtin attributes and the custom map.
/// Builtin attributes keep their defaults when absent.
fn build_frontmatter(entries : Array[(String, String)]) -> Frontmatter {
  let mut builtin = default_builtin
  let custom = Map([])
  for entry in entries {
    match entry.0 {
      "lang" => builtin = { ..builtin, lang: entry.1, }
      "paper" =>
        builtin = { ..builtin, paper: Paper::from_string(entry.1).unwrap(), }
      "title" => builtin = { ..builtin, title: entry.1, }
      _ => custom.set(entry.0, entry.1)
    }
  }
  { builtin, custom, }
}

///|
/// Parses a frontmatter block, returning the entries split into builtin
/// attributes and custom data. Duplicate keys overwrite, keeping the first
/// position.
pub let frontmatter : @talc.StringParser[Frontmatter] = fm_opener
  .then(fm_body)
  .skip(fm_closer)
  .map(build_frontmatter)
