///|
fn parse_name(cursor : Cursor) -> (String, Cursor) {
  let start = cursor.index
  let mut index = cursor.index
  while index < cursor.chars.length() {
    let ch = cursor.chars[index]
    if is_name_boundary(ch) {
      break
    }
    if ch == '\\' && index + 1 < cursor.chars.length() {
      index += 2
    } else {
      index += 1
    }
  }
  (cursor.slice_to_string(start, index), cursor.at(index))
}

///|
fn parse_raw_string(cursor : Cursor) -> Result[(String, Cursor), Diagnostic] {
  let buffer : Array[Char] = []
  let mut index = cursor.index + 1
  while index < cursor.chars.length() {
    let ch = cursor.chars[index]
    if ch == '\\' &&
      index + 1 < cursor.chars.length() &&
      cursor.chars[index + 1] == '`' {
      buffer.push('`')
      index += 2
      continue
    }
    if ch == '`' {
      return Ok((String::from_array(buffer.view()), cursor.at(index + 1)))
    }
    buffer.push(ch)
    index += 1
  }
  Err(cursor.error("unterminated raw string"))
}

///|
fn parse_quoted_string(
  cursor : Cursor,
) -> Result[(Interpolation, Cursor), Diagnostic] {
  let parts : Interpolation = []
  let buffer : Array[Char] = []
  let mut index = cursor.index + 1
  while index < cursor.chars.length() {
    let ch = cursor.chars[index]
    if ch == '\\' && index + 1 < cursor.chars.length() {
      buffer.push(cursor.chars[index + 1])
      index += 2
      continue
    }
    if ch == '"' {
      flush_interpolation_literal(parts, buffer)
      return Ok((parts, cursor.at(index + 1)))
    }
    if ch == '(' {
      flush_interpolation_literal(parts, buffer)
      let ref_start = cursor.at(index)
      let (name, after_name) = parse_name(ref_start.advance(1))
      guard !name.is_empty() && after_name.peek() == Some(')') else {
        return Err(ref_start.error("invalid interpolation name"))
      }
      parts.push(Name(name))
      index = after_name.index + 1
      continue
    }
    buffer.push(ch)
    index += 1
  }
  Err(cursor.error("unterminated interpolated string"))
}

///|
fn flush_interpolation_literal(
  parts : Interpolation,
  buffer : Array[Char],
) -> Unit {
  guard !buffer.is_empty() else { return }
  parts.push(Literal(String::from_array(buffer.view())))
  buffer.clear()
}

///|
// Consumes plain text until the next syntax boundary. Soft line breaks are
// layout: they do not emit text, while blank lines emit "\n\n" for paragraph
// splitting in the HTML backend.
fn parse_text(cursor : Cursor) -> (String, Cursor) {
  let buffer : Array[Char] = []
  let mut index = cursor.index
  while index < cursor.chars.length() && !is_text_stop(cursor, index) {
    index = consume_text_unit(cursor.chars, index, buffer)
  }
  (smart_dashes(String::from_array(buffer.view())), cursor.at(index))
}

///|
fn is_text_stop(cursor : Cursor, index : Int) -> Bool {
  is_text_boundary(cursor.chars[index]) || is_line_comment_start(cursor, index)
}

///|
// Advances over one logical text unit and appends any emitted characters to
// buffer. The returned index always moves forward.
fn consume_text_unit(
  chars : Array[Char],
  index : Int,
  buffer : Array[Char],
) -> Int {
  if is_crlf_at(chars, index) {
    index + 1
  } else if is_newline(chars[index]) {
    consume_text_newline(chars, index, buffer)
  } else if is_escaped_text_char_at(chars, index) {
    buffer.push(chars[index + 1])
    index + 2
  } else {
    buffer.push(chars[index])
    index + 1
  }
}

///|
// Single newlines only join source lines. A second newline after optional
// layout spaces is preserved as the paragraph-break marker.
fn consume_text_newline(
  chars : Array[Char],
  index : Int,
  buffer : Array[Char],
) -> Int {
  let next = skip_layout_spaces(chars, index + 1)
  if next < chars.length() && is_newline(chars[next]) {
    buffer.push('\n')
    buffer.push('\n')
    next + 1
  } else {
    next
  }
}

///|
fn is_crlf_at(chars : Array[Char], index : Int) -> Bool {
  chars[index] == '\r' && index + 1 < chars.length() && is_newline(chars[index + 1])
}

///|
fn skip_layout_spaces(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  while index < chars.length() && is_layout_space(chars[index]) {
    index += 1
  }
  index
}

///|
// Backslash escapes are intentionally narrow: unknown escapes keep the
// backslash literal instead of silently deleting it.
fn is_escaped_text_char_at(chars : Array[Char], index : Int) -> Bool {
  chars[index] == '\\' &&
  index + 1 < chars.length() &&
  is_escapable_text_char(chars[index + 1])
}

///|
fn parse_emphasis_or_text(
  cursor : Cursor,
) -> Result[(Node, Cursor), Diagnostic] {
  if cursor.starts_with("**") {
    return capture_until(cursor.advance(2), "**").map(result => {
      (
        Node::Element(
          "strong",
          [],
          [Node::Text(smart_dashes(result.0), cursor.advance(2).source_span())],
          cursor.source_span(),
        ),
        result.1,
      )
    })
  }
  capture_until(cursor.advance(1), "*").map(result => {
    (
      Node::Element(
        "em",
        [],
        [Node::Text(smart_dashes(result.0), cursor.advance(1).source_span())],
        cursor.source_span(),
      ),
      result.1,
    )
  })
}

///|
fn capture_until(
  cursor : Cursor,
  marker : String,
) -> Result[(String, Cursor), Diagnostic] {
  let buffer : Array[Char] = []
  let mut scan = cursor
  while !scan.is_end() {
    if scan.starts_with(marker) {
      return Ok(
        (String::from_array(buffer.view()), scan.advance(marker.length())),
      )
    }
    buffer.push(scan.chars[scan.index])
    scan = scan.advance(1)
  }
  Err(cursor.error("unterminated inline marker"))
}

///|
fn smart_dashes(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if index + 2 < chars.length() &&
      chars[index] == '-' &&
      chars[index + 1] == '-' &&
      chars[index + 2] == '-' {
      out.push('—')
      index += 3
      continue
    }
    if index + 1 < chars.length() &&
      chars[index] == '-' &&
      chars[index + 1] == '-' {
      out.push('–')
      index += 2
      continue
    }
    out.push(chars[index])
    index += 1
  }
  String::from_array(out.view())
}
