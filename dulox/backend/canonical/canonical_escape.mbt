///|
/// Joins rendered items in math mode. A raw space is inserted between a
/// trailing and a leading letter so that bare control words (`\sum`, `\lim`,
/// `\quad`) stay distinct from a following letter; math-mode spaces carry no
/// visual spacing, so the insertion is invisible.
fn join_math(items : Array[String]) -> String {
  let builder = StringBuilder()
  let mut prev = ""
  for text in items {
    guard text != "" else { continue }
    if prev != "" && needs_space(prev, text) {
      builder.write_string(" ")
    }
    builder.write_string(text)
    prev = text
  }
  builder.to_string()
}

///|
/// Joins rendered items without inserted spacing. Used in text mode, where
/// spaces are significant and adjacent letters form a single word, and in
/// tight math contexts (font bodies) whose items are single atoms with no
/// bare control words.
fn join_tight(items : Array[String]) -> String {
  let builder = StringBuilder()
  for text in items {
    builder.write_string(text)
  }
  builder.to_string()
}

///|
fn needs_space(left : String, right : String) -> Bool {
  is_bare_control_word(left) &&
  !right.is_empty() &&
  is_ascii_letter_code(right[0])
}

///|
/// A bare control word (one that would absorb a following letter into itself,
/// e.g. `\lim`, `\sum`, `\quad`) must be separated from a following letter.
/// Braced commands and plain letters need no separation.
fn is_bare_control_word(text : String) -> Bool {
  text.has_prefix("\\") &&
  !text.contains("{") &&
  !text.contains("}") &&
  !text.is_empty() &&
  is_ascii_letter_code(text[text.length() - 1])
}

///|
/// UTF-16 code units are compared to the ASCII letter ranges directly, since
/// all output candidates for the space rule are ASCII.
fn is_ascii_letter_code(code : UInt16) -> Bool {
  let c = code.to_int()
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

///|
fn braced(content : String) -> String {
  "{\{content}}"
}
