//! Scanners for fragments of CommonMark syntax.
//!
//! Byte-oriented scanning over a UTF-8 `Bytes` view.

///|
fn Byte::is_ascii_whitespace_no_nl(c : Byte) -> Bool {
  c.to_char().is_ascii_whitespace() && c != b'\n' && c != b'\r'
}

///|
fn Byte::is_ascii_alphanumeric(c : Byte) -> Bool {
  let ch = c.to_char()
  ch.is_ascii_alphabetic() || ch.is_ascii_digit()
}

///|
fn Byte::is_ascii_letterdigitdash(c : Byte) -> Bool {
  c == b'-' || c.is_ascii_alphanumeric()
}

///|
fn Byte::is_valid_unquoted_attr_value_char(c : Byte) -> Bool {
  let b = c.to_int()
  b != 0x27 &&
  b != 0x22 &&
  b != 0x20 &&
  b != 0x3d &&
  b != 0x3e &&
  b != 0x3c &&
  b != 0x60 &&
  b != 0x0a &&
  b != 0x0d
}

///|
/// scan a single character
fn scan_ch(data : BytesView, c : Byte) -> Int {
  if !data.is_empty() && data.unsafe_get(0) == c {
    1
  } else {
    0
  }
}

///|
fn scan_while(data : BytesView, f : (Byte) -> Bool) -> Int {
  let mut i = 0
  while i < data.length() && f(data.unsafe_get(i)) {
    i += 1
  }
  i
}

///|
fn scan_while_max(data : BytesView, f : (Byte) -> Bool, m : Int) -> Int {
  let mut i = 0
  while i < data.length() && i < m && f(data.unsafe_get(i)) {
    i += 1
  }
  i
}

///|
fn scan_rev_while(data : BytesView, f : (Byte) -> Bool) -> Int {
  let mut i = data.length()
  while i > 0 && f(data.unsafe_get(i - 1)) {
    i -= 1
  }
  data.length() - i
}

///|
fn scan_ch_repeat(data : BytesView, c : Byte) -> Int {
  scan_while(data, x => x == c)
}

// Note: this scans ASCII whitespace only, for Unicode whitespace use
// a different function.

///|
fn scan_whitespace_no_nl(data : BytesView) -> Int {
  scan_while(data, c => c.is_ascii_whitespace_no_nl())
}

///|
fn scan_eol(bytes : BytesView) -> Int? {
  guard !bytes.is_empty() else { return Some(0) }
  let c = bytes.unsafe_get(0)
  guard c != b'\n' else { return Some(1) }
  guard c != b'\r' else {
    if bytes.length() >= 2 && bytes.unsafe_get(1) == b'\n' {
      return Some(2)
    }
    return Some(1)
  }
  None
}

///|
fn scan_blank_line(bytes : BytesView) -> Int? {
  let i = scan_whitespace_no_nl(bytes)
  scan_eol(bytes.exact_view(start=i)).map(n => i + n)
}

///|
fn scan_nextline(bytes : BytesView) -> Int {
  // Per CommonMark, a line ending is LF, CRLF, or a lone CR.
  let mut i = 0
  while i < bytes.length() {
    let c = bytes.unsafe_get(i)
    guard c != b'\n' else { return i + 1 }
    if c == b'\r' {
      guard !(bytes.length() > i + 1 && bytes.unsafe_get(i + 1) == b'\n') else {
        return i + 2
      }
      return i + 1
    }
    i += 1
  }
  bytes.length()
}

// return: end byte for closing code fence, or None
// if the line is ! a closing code fence

///|
fn scan_closing_code_fence(
  bytes : BytesView,
  fence_char : Byte,
  n_fence_char : Int,
) -> Int? {
  guard !bytes.is_empty() else { return Some(0) }
  let num_fence_chars_found = scan_ch_repeat(bytes, fence_char)
  guard num_fence_chars_found >= n_fence_char else { return None }
  let mut i = num_fence_chars_found
  let num_trailing_spaces = scan_ch_repeat(bytes.exact_view(start=i), b' ')
  i += num_trailing_spaces
  scan_eol(bytes.exact_view(start=i)).map(_ => i)
}

// return: end byte for closing metadata block, or None
// if the line is ! a closing metadata block

///|
fn scan_closing_metadata_block(bytes : BytesView, fence_char : Byte) -> Int? {
  let mut num_fence_chars_found = scan_ch_repeat(bytes, fence_char)
  if num_fence_chars_found != 3 {
    // if YAML style metadata block the closing character can also be `.`
    guard fence_char == b'-' else { return None }
    num_fence_chars_found = scan_ch_repeat(bytes, b'.')
    guard num_fence_chars_found == 3 else { return None }
  }
  let mut i = num_fence_chars_found
  let num_trailing_spaces = scan_ch_repeat(bytes.exact_view(start=i), b' ')
  i += num_trailing_spaces
  scan_eol(bytes.exact_view(start=i)).map(_ => i)
}

// returned pair is (number of bytes, number of spaces)

///|
fn calc_indent(text : BytesView, max : Int) -> (Int, Int) {
  let mut spaces = 0
  let mut offset = 0

  let mut i = 0
  while i < text.length() {
    offset = i
    let b = text.unsafe_get(i)
    if b == b' ' {
      spaces += 1
      if spaces == max {
        break
      }
    } else if b == b'\t' {
      let new_spaces = spaces + 4 - (spaces & 3)
      if new_spaces > max {
        break
      }
      spaces = new_spaces
    } else {
      break
    }
    i += 1
  }

  (offset, spaces)
}

///|
/// Scan hrule opening sequence.
///
/// Returns Ok(x) when it finds an hrule, where x is the
/// size of line containing the hrule, including the trailing newline.
///
/// Returns Err(x) when it does ! find an hrule and x is
/// the offset in data before no hrule can appear.
fn scan_hrule(bytes : BytesView) -> Result[Int, Int] {
  guard bytes.length() >= 3 else { return Err(0) }
  let c = bytes.unsafe_get(0)
  guard c == b'*' || c == b'-' || c == b'_' else { return Err(0) }
  let mut n = 0
  let mut i = 0

  while i < bytes.length() {
    let b = bytes.unsafe_get(i)
    if b == b'\n' || b == b'\r' {
      i += match scan_eol(bytes.exact_view(start=i)) {
        Some(e) => e
        None => 0
      }
      break
    } else if b == c {
      n += 1
    } else if b == b' ' || b == b'\t' {
      ()
    } else {
      return Err(i)
    }
    i += 1
  }
  guard n >= 3 else { Err(i) }
  Ok(i)
}

///|
/// Scan an ATX heading opening sequence.
///
/// Returns number of bytes in prefix and level.
fn scan_atx_heading(data : BytesView) -> HeadingLevel? {
  let level = scan_ch_repeat(data, b'#')
  let ok = if level < data.length() {
    data.unsafe_get(level).to_char().is_ascii_whitespace()
  } else {
    true
  }
  if ok {
    int_to_heading_level(level)
  } else {
    None
  }
}

///|
/// Scan a setext heading underline.
///
/// Returns number of bytes in line (including trailing newline) and level.
fn scan_setext_heading(data : BytesView) -> (Int, HeadingLevel)? {
  guard !data.is_empty() else { return None }
  let c = data.unsafe_get(0)
  let level = if c == b'=' { H1 } else if c == b'-' { H2 } else { return None }
  let mut i = 1 + scan_ch_repeat(data.exact_view(start=1), c)
  match scan_blank_line(data.exact_view(start=i)) {
    Some(n) => {
      i += n
      Some((i, level))
    }
    None => None
  }
}

// returns number of bytes in line (including trailing
// newline) and column alignments

///|
fn scan_table_head(data : BytesView) -> (Int, Array[Alignment]) {
  let (i0, spaces) = calc_indent(data, 4)
  let mut i = i0
  guard !(spaces > 3 || i == data.length()) else { return (0, []) }
  let cols : Array[Alignment] = []
  let mut active_col : Alignment = None
  let mut start_col = true
  let mut found_pipe = false
  let mut found_hyphen = false
  let mut found_hyphen_in_col = false
  if data.unsafe_get(i) == b'|' {
    i += 1
    found_pipe = true
  }
  while i < data.length() {
    match scan_eol(data.exact_view(start=i)) {
      Some(n) => {
        i += n
        break
      }
      None => ()
    }
    let c = data.unsafe_get(i)
    if c == b' ' {
      ()
    } else if c == b':' {
      active_col = match (start_col, active_col) {
        (true, None) => Left
        (false, Left) => Center
        (false, None) => Right
        _ => active_col
      }
      start_col = false
    } else if c == b'-' {
      start_col = false
      found_hyphen = true
      found_hyphen_in_col = true
    } else if c == b'|' {
      start_col = true
      found_pipe = true
      cols.push(active_col)
      active_col = None
      guard found_hyphen_in_col else {
        // It isn't a table head if it has back-to-back pipes.
        return (0, [])
      }
      found_hyphen_in_col = false
    } else {
      // It isn't a table head if it has characters outside the allowed set.
      return (0, [])
    }
    i += 1
  }

  if !start_col {
    cols.push(active_col)
  }
  guard found_pipe && found_hyphen else {
    // It isn't a table head if it doesn't have at least one pipe or hyphen.
    return (0, [])
  }

  (i, cols)
}

///|
/// Scan code fence.
///
/// Returns number of bytes scanned and the char that is repeated to make the
/// code fence.
fn scan_code_fence(data : BytesView) -> (Int, Byte)? {
  guard !data.is_empty() else { return None }
  let c = data.unsafe_get(0)
  guard c == b'`' || c == b'~' else { return None }
  let i = 1 + scan_ch_repeat(data.exact_view(start=1), c)
  if i >= 3 {
    if c == b'`' {
      let suffix = data.exact_view(start=i)
      let next_line = i + scan_nextline(suffix)
      // FIXME: make sure this is correct
      let mut j = 0
      while j < next_line - i {
        guard suffix.unsafe_get(j) != b'`' else { return None }
        j += 1
      }
    }
    Some((i, c))
  } else {
    None
  }
}

///|
fn scan_interrupting_container_extensions_fence(data : BytesView) -> Bool {
  let fence_length = scan_ch_repeat(data, b':')
  let kind_start = fence_length +
    scan_whitespace_no_nl(data.exact_view(start=fence_length))
  let kind_length = scan_while(data.exact_view(start=kind_start), c => {
    c.is_ascii_alphanumeric() ||
    c == b'_' ||
    c == b'-' ||
    c == b':' ||
    c == b'.'
  })
  fence_length > 2 && kind_length > 0
}

///|
/// Scan metadata block, returning the number of delimiter bytes
/// (always 3 for now) and the delimiter character.
fn scan_metadata_block(
  data : BytesView,
  yaml_style_enabled : Bool,
  pluses_style_enabled : Bool,
) -> (Int, Byte)? {
  // Only if metadata blocks are enabled
  guard yaml_style_enabled || pluses_style_enabled else { None }
  guard !data.is_empty() else { return None }
  let c = data.unsafe_get(0)
  guard (c == b'-' && yaml_style_enabled) || (c == b'+' && pluses_style_enabled) else {
    return None
  }
  let i = 1 + scan_ch_repeat(data.exact_view(start=1), c)
  // Only trailing spaces after the delimiters in the line
  let next_line = scan_nextline(data.exact_view(start=i))
  let mut j = 0
  while j < next_line {
    guard data.unsafe_get(i + j).to_char().is_ascii_whitespace() else {
      return None
    }
    j += 1
  }
  guard i == 3 else { None }
  // Search the closing sequence
  let mut j = i
  let mut first_line = true
  while j < data.length() {
    j += scan_nextline(data.exact_view(start=j))
    let closed = scan_closing_metadata_block(data.exact_view(start=j), c) is Some(_)
    // The first line of the metadata block cannot be an empty line
    // nor the end of the block
    if first_line {
      guard !(closed || scan_blank_line(data.exact_view(start=j)) is Some(_)) else {
        return None
      }
      first_line = false
    }
    guard !closed else { return Some((i, c)) }
  }
  None
}

///|
fn scan_blockquote_start(data : BytesView) -> Int? {
  guard !data.is_empty() && data.unsafe_get(0) == b'>' else { None }
  let space = if data.length() >= 2 && data.unsafe_get(1) == b' ' {
    1
  } else {
    0
  }
  Some(1 + space)
}

///|
/// return number of bytes scanned, delimiter, start index, and indent
fn scan_listitem(bytes : BytesView) -> (Int, Byte, Int, Int)? {
  guard !bytes.is_empty() else { return None }
  let mut c = bytes.unsafe_get(0)
  let (w, start) = if c == b'-' || c == b'+' || c == b'*' {
    (1, 0)
  } else if c >= b'0' && c <= b'9' {
    let (length, start) = parse_decimal(bytes, 9)
    guard length < bytes.length() else { return None }
    c = bytes.unsafe_get(length)
    guard c == b'.' || c == b')' else { return None }
    (length + 1, start)
  } else {
    return None
  }
  // TODO: replace calc_indent with scan_leading_whitespace, for tab correctness
  let (postn0, postindent0) = calc_indent(bytes.exact_view(start=w), 5)
  let mut postn = postn0
  let mut postindent = postindent0
  if postindent == 0 {
    match scan_eol(bytes.exact_view(start=w)) {
      Some(_) => ()
      None => return None
    }
    postindent += 1
  } else if postindent > 4 {
    postn = 1
    postindent = 1
  }
  if scan_blank_line(bytes.exact_view(start=w)) is Some(_) {
    postn = 0
    postindent = 1
  }
  Some((w + postn, c, start, w + postindent))
}

// returns (number of bytes, parsed decimal)

///|
fn parse_decimal(bytes : BytesView, limit : Int) -> (Int, Int) {
  let mut count = 0
  let mut acc = 0
  while count < bytes.length() && count < limit {
    let b = bytes.unsafe_get(count)
    if !b.to_char().is_ascii_digit() {
      break
    }
    let digit = b.to_int() - 0x30
    let new_acc = acc * 10 + digit
    if new_acc < acc {
      // overflow
      break
    }
    acc = new_acc
    count += 1
  }
  (count, acc)
}

// returns (number of bytes, parsed hex)

///|
fn parse_hex(bytes : BytesView, limit : Int) -> (Int, Int) {
  let mut count = 0
  let mut acc = 0
  while count < bytes.length() && count < limit {
    let mut c = bytes.unsafe_get(count).to_int()
    let digit = if c >= 0x30 && c <= 0x39 {
      c - 0x30
    } else {
      // make lower case
      c = c | 0x20
      if c >= 0x61 && c <= 0x66 {
        c - 0x61 + 10
      } else {
        break
      }
    }
    let new_acc = acc * 16 + digit
    if new_acc < acc {
      break
    }
    acc = new_acc
    count += 1
  }
  (count, acc)
}

///|
fn char_from_codepoint(input : Int) -> Char? {
  // Codepoint 0 is treated as invalid (emits U+FFFD).
  guard input != 0 else { return None }
  Int::to_char(input)
}

// doesn't bother to check data[0] == '&'

///|
fn scan_entity(bytes : BytesView) -> (Int, String?) {
  let mut end = 1
  if bytes.length() > end && bytes.unsafe_get(end) == b'#' {
    end += 1
    let is_hex = end < bytes.length() &&
      (bytes.unsafe_get(end).to_int() | 0x20) == 0x78
    let (bytecount, codepoint) = if is_hex {
      end += 1
      parse_hex(bytes.exact_view(start=end), 6)
    } else {
      parse_decimal(bytes.exact_view(start=end), 7)
    }
    end += bytecount
    if bytecount == 0 || bytes.length() <= end || bytes.unsafe_get(end) != b';' {
      (0, None)
    } else {
      (
        end + 1,
        Some(
          char_from_codepoint(codepoint).map_or("\u{fffd}", c => c.to_string()),
        ),
      )
    }
  } else {
    end += scan_while(bytes.exact_view(start=end), c => c.is_ascii_alphanumeric())
    if bytes.length() > end && bytes.unsafe_get(end) == b';' {
      match get_entity(bytes.exact_view(start=1, end~)) {
        Some(value) => (end + 1, Some(value))
        None => (0, None)
      }
    } else {
      (0, None)
    }
  }
}

///|
fn scan_wikilink_pipe(
  data : BytesView,
  start_ix : Int,
  len : Int,
) -> (Int, Int)? {
  let end_ix = (start_ix + len).min(data.length())
  let mut i = start_ix
  while i < end_ix {
    guard data.unsafe_get(i) != b'|' else { return Some((i + 1, i)) }
    i += 1
  }
  None
}

// note: dest returned is raw, still needs to be unescaped
// returns (bytes consumed, dest_start, dest_end)

///|
fn scan_link_dest(
  data : BytesView,
  start_ix : Int,
  max_next : Int,
) -> (Int, Int, Int)? {
  let bytes = data.exact_view(start=start_ix)
  let mut i = scan_ch(bytes, b'<')

  if i != 0 {
    // pointy links
    while i < bytes.length() {
      let c = bytes.unsafe_get(i)
      guard !(c == b'\n' || c == b'\r' || c == b'<') else { return None }
      guard c != b'>' else { return Some((i + 1, start_ix + 1, start_ix + i)) }
      if c == b'\\' &&
        i + 1 < bytes.length() &&
        is_ascii_punctuation(bytes.unsafe_get(i + 1).to_int()) {
        i += 1
      }
      i += 1
    }
    None
  } else {
    // non-pointy links
    let mut nest = 0
    while i < bytes.length() {
      let c = bytes.unsafe_get(i)
      if c.to_int() >= 0x00 && c.to_int() <= 0x20 {
        break
      }
      if c == b'(' {
        guard nest <= max_next else { return None }
        nest += 1
      } else if c == b')' {
        if nest == 0 {
          break
        }
        nest -= 1
      } else if c == b'\\' &&
        i + 1 < bytes.length() &&
        is_ascii_punctuation(bytes.unsafe_get(i + 1).to_int()) {
        i += 1
      }
      i += 1
    }
    guard nest == 0 else { return None }
    Some((i, start_ix, start_ix + i))
  }
}

///|
/// Returns bytes scanned
fn scan_attribute_name(data : BytesView) -> Int? {
  guard !data.is_empty() else { return None }
  let c = data.unsafe_get(0)
  guard c.to_char().is_ascii_alphabetic() || c == b'_' || c == b':' else {
    None
  }
  Some(
    1 +
    scan_while(data.exact_view(start=1), c => {
      c.is_ascii_alphanumeric() ||
      c == b'_' ||
      c == b'.' ||
      c == b':' ||
      c == b'-'
    }),
  )
}

///|
/// State shared between attribute-scanning functions.
priv struct AttrScanState {
  buffer : Buffer
  mut last_buf_index : Int
}

///|
fn attr_state_new() -> AttrScanState {
  { buffer: Buffer(size_hint=0), last_buf_index: 0, }
}

///|
/// Scans whitespace and possibly newlines according to the
/// behavior defined by the newline handler. When bytes are skipped,
/// all preceding non-skipped bytes are pushed to the buffer.
fn AttrScanState::scan_whitespace_with_newline_handler(
  self : AttrScanState,
  data : BytesView,
  i : Int,
  newline_handler : ((BytesView) -> Int)?,
) -> Int? {
  let mut i = i
  while i < data.length() {
    guard data.unsafe_get(i).to_char().is_ascii_whitespace() else {
      return Some(i)
    }
    match scan_eol(data.exact_view(start=i)) {
      Some(eol_bytes) =>
        match newline_handler {
          Some(handler) => {
            i += eol_bytes
            let skipped_bytes = handler(data.exact_view(start=i))

            if skipped_bytes > 0 {
              let start = self.last_buf_index
              self.buffer.write_bytesview(data.exact_view(start~, end=i))
              self.last_buf_index = i + skipped_bytes
            }

            i += skipped_bytes
          }
          None => return None
        }
      None => i += 1
    }
  }

  Some(i)
}

///|
/// Scans whitespace and possible newlines according to the behavior defined
/// by the newline handler.
fn scan_whitespace_with_newline_handler_without_buffer(
  data : BytesView,
  i : Int,
  newline_handler : ((BytesView) -> Int)?,
) -> Int? {
  let mut i = i
  while i < data.length() {
    guard data.unsafe_get(i).to_char().is_ascii_whitespace() else {
      return Some(i)
    }
    match scan_eol(data.exact_view(start=i)) {
      Some(eol_bytes) =>
        match newline_handler {
          Some(handler) => {
            i += eol_bytes
            let skipped_bytes = handler(data.exact_view(start=i))
            i += skipped_bytes
          }
          None => return None
        }
      None => i += 1
    }
  }

  Some(i)
}

///|
/// Returns the index immediately following the attribute value on success.
fn AttrScanState::scan_attribute_value(
  self : AttrScanState,
  data : BytesView,
  i : Int,
  newline_handler : ((BytesView) -> Int)?,
) -> Int? {
  let mut i = i
  guard i < data.length() else { return None }
  let c = data.unsafe_get(i)
  if c == b'"' || c == b'\'' {
    let quote = c
    i += 1
    while i < data.length() {
      guard data.unsafe_get(i) != quote else { return Some(i + 1) }
      match scan_eol(data.exact_view(start=i)) {
        Some(eol_bytes) =>
          match newline_handler {
            Some(handler) => {
              i += eol_bytes
              let skipped_bytes = handler(data.exact_view(start=i))

              if skipped_bytes > 0 {
                let start = self.last_buf_index
                self.buffer.write_bytesview(data.exact_view(start~, end=i))
                self.last_buf_index = i + skipped_bytes
              }
              i += skipped_bytes
            }
            None => return None
          }
        None => i += 1
      }
    }
    return None
  } else {
    let is_special = c == b' ' ||
      c == b'=' ||
      c == b'>' ||
      c == b'<' ||
      c == b'`' ||
      c == b'\n' ||
      c == b'\r'
    guard !is_special else { return None }
    // unquoted attribute value
    i += scan_attr_value_chars(data.exact_view(start=i))
  }

  Some(i)
}

///|
/// Returns the index immediately following the attribute on success.
fn AttrScanState::scan_attribute(
  self : AttrScanState,
  data : BytesView,
  ix : Int,
  newline_handler : ((BytesView) -> Int)?,
) -> Int? {
  let mut ix = ix
  guard scan_attribute_name(data.exact_view(start=ix)) is Some(n) else { return None }
  ix += n
  let ix_after_attribute = ix
  guard scan_whitespace_with_newline_handler_without_buffer(
      data, ix, newline_handler,
    )
    is Some(n) else {
    return None
  }
  ix = n
  if data.length() > ix && data.unsafe_get(ix) == b'=' {
    guard self.scan_whitespace_with_newline_handler(
        data, ix_after_attribute, newline_handler,
      )
      is Some(n) else {
      return None
    }
    ix = n
    ix += 1
    guard self.scan_whitespace_with_newline_handler(data, ix, newline_handler)
      is Some(n) else {
      return None
    }
    ix = n
    guard self.scan_attribute_value(data, ix, newline_handler) is Some(n) else {
      return None
    }
    ix = n
    Some(ix)
  } else {
    // Leave whitespace for next attribute.
    Some(ix_after_attribute)
  }
}

///|
fn scan_attr_value_chars(data : BytesView) -> Int {
  scan_while(data, c => c.is_valid_unquoted_attr_value_char())
}

///|
/// Remove backslash escapes and resolve entities
fn unescape(input : Bytes, from : Int, to : Int, is_in_table : Bool) -> String {
  let result = StringBuilder()
  let mut mark = from
  let mut i = from
  let bytes = input
  while i < to {
    let c = bytes.unsafe_get(i)
    // Tables are special, because they're parsed as-if the tables
    // were parsed in a discrete pass, changing `\|` to `|`, and then
    // passing the changed string to the inline parser.
    let is_table_double_escape = is_in_table &&
      c == b'\\' &&
      i + 2 < to &&
      bytes.unsafe_get(i + 1) == b'\\' &&
      bytes.unsafe_get(i + 2) == b'|'
    if is_table_double_escape {
      // even number of `\`s before pipe
      // odd number is handled in the normal way below
      write_range(result, bytes, mark, i)
      mark = i + 2
      i += 3
    } else {
      let is_escape = c == b'\\' &&
        i + 1 < to &&
        is_ascii_punctuation(bytes.unsafe_get(i + 1).to_int())
      if is_escape {
        write_range(result, bytes, mark, i)
        mark = i + 1
        i += 2
      } else if c == b'&' {
        match scan_entity(bytes.exact_view(start=i, end=to)) {
          (n, Some(value)) => {
            write_range(result, bytes, mark, i)
            result.write_string(value)
            i += n
            mark = i
          }
          _ => i += 1
        }
      } else if c == b'\r' {
        write_range(result, bytes, mark, i)
        i += 1
        mark = i
      } else if c == b'\x00' {
        write_range(result, bytes, mark, i)
        result.write_string("\u{fffd}")
        i += 1
        mark = i
      } else {
        i += 1
      }
    }
  }
  write_range(result, bytes, mark, to)
  result.to_string()
}

///|
fn write_range(
  buf : StringBuilder,
  bytes : BytesView,
  from : Int,
  to : Int,
) -> Unit {
  if to > from {
    buf.write_stringview(
      @utf8.decode_lossy(bytes.exact_view(start=from, end=to)).exact_view(),
    )
  }
}

///|
/// Assumes `data` is preceded by `<`.
fn starts_html_block_type_6(data : BytesView) -> Bool {
  let i = scan_ch(data, b'/')
  let tail = data.exact_view(start=i)
  let n = scan_while(tail, c => c.is_ascii_alphanumeric())
  guard is_html_tag(tail.exact_view(start=0, end=n)) else { return false }

  // Starting condition says the next byte must be either a space, a tab,
  // the end of the line, the string >, or the string />
  let tail = tail.exact_view(start=n)
  tail.is_empty() ||
  tail.unsafe_get(0) == b' ' ||
  tail.unsafe_get(0) == b'\t' ||
  tail.unsafe_get(0) == b'\r' ||
  tail.unsafe_get(0) == b'\n' ||
  tail.unsafe_get(0) == b'>' ||
  (
    tail.length() >= 2 &&
    tail.unsafe_get(0) == b'/' &&
    tail.unsafe_get(1) == b'>'
  )
}

///|
fn is_html_tag(tag : BytesView) -> Bool {
  let mut lo = 0
  let mut hi = html_tags().length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let cmp = compare_case_insensitive(
      tag,
      @utf8.encode(html_tags()[mid]).exact_view(),
    )
    guard cmp != 0 else { return true }
    if cmp < 0 {
      hi = mid - 1
    } else {
      lo = mid + 1
    }
  }
  false
}

///|
fn compare_case_insensitive(a : BytesView, b : BytesView) -> Int {
  let n = a.length().min(b.length())
  let mut i = 0
  while i < n {
    let x = a.unsafe_get(i).to_int() | 0x20
    let y = b.unsafe_get(i).to_int() | 0x20
    guard x == y else { return x - y }
    i += 1
  }
  a.length() - b.length()
}

// sorted for binary search

///|
fn html_tags() -> Array[String] {
  [
    "address", "article", "aside", "base", "basefont", "blockquote", "body", "caption",
    "center", "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl", "dt",
    "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset", "h1",
    "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend",
    "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup",
    "option", "p", "param", "search", "section", "summary", "table", "tbody", "td",
    "tfoot", "th", "thead", "title", "tr", "track", "ul",
  ]
}

///|
/// Assumes that `data` starts with `<`.
/// Returns the index into data directly after the html tag on success.
fn scan_html_type_7(data : BytesView) -> Int? {
  // Block type html does ! allow for newlines, so we
  // do ! pass a newline handler.
  match scan_html_block_inner(data, None) {
    Some((_span, i)) => scan_blank_line(data.exact_view(start=i)).map(_ => i)
    None => None
  }
}

///|
/// Assumes that `data` starts with `<`.
/// Returns the number of bytes scanned and the html in case of success.
/// When some bytes were skipped, because the html was split over
/// multiple leafs (e.g. over multiple lines in a blockquote),
/// the html is returned as a vector of bytes.
fn scan_html_block_inner(
  data : BytesView,
  newline_handler : ((BytesView) -> Int)?,
) -> (Array[Byte], Int)? {
  let state = attr_state_new()

  let close_tag_bytes = scan_ch(data.exact_view(start=1), b'/')
  let l = scan_while(data.exact_view(start=1 + close_tag_bytes), c => {
    c.to_char().is_ascii_alphabetic()
  })
  guard l != 0 else { return None }
  let mut i = 1 + close_tag_bytes + l
  i += scan_while(data.exact_view(start=i), c => c.is_ascii_letterdigitdash())

  if close_tag_bytes == 0 {
    while true {
      let old_i = i
      while true {
        i += scan_whitespace_no_nl(data.exact_view(start=i))
        match scan_eol(data.exact_view(start=i)) {
          Some(eol_bytes) => {
            guard eol_bytes != 0 else { return None }
            match newline_handler {
              Some(handler) => {
                i += eol_bytes
                let skipped_bytes = handler(data.exact_view(start=i))

                if skipped_bytes > 0 {
                  state.buffer.write_bytesview(
                    data.exact_view(start=state.last_buf_index, end=i),
                  )
                  i += skipped_bytes
                  state.last_buf_index = i
                }
              }
              None => return None
            }
          }
          None => break
        }
      }
      if data.length() > i &&
        (data.unsafe_get(i) == b'/' || data.unsafe_get(i) == b'>') {
        break
      }
      guard old_i != i else {
        // No whitespace, which is mandatory.
        return None
      }
      guard state.scan_attribute(data, i, newline_handler) is Some(n) else {
        return None
      }
      i = n
    }
  }

  i += scan_whitespace_no_nl(data.exact_view(start=i))

  if close_tag_bytes == 0 {
    i += scan_ch(data.exact_view(start=i), b'/')
  }

  guard data.length() > i && data.unsafe_get(i) == b'>' else { None }
  i += 1
  let buffer = if state.buffer.is_empty() {
    []
  } else {
    state.buffer.write_bytesview(data.exact_view(start=state.last_buf_index, end=i))
    state.buffer.to_bytes().to_array()
  }
  Some((buffer, i))
}

///|
/// Returns (next_byte_offset, uri, type)
fn scan_autolink(text : BytesView, start_ix : Int) -> (Int, String, LinkType)? {
  match scan_uri(text, start_ix) {
    Some((bytes, uri)) => Some((bytes, uri, Autolink))
    None =>
      match scan_email(text, start_ix) {
        Some((bytes, uri)) => Some((bytes, uri, Email))
        None => None
      }
  }
}

///|
/// Returns (next_byte_offset, uri)
fn scan_uri(text : BytesView, start_ix : Int) -> (Int, String)? {
  let bytes = text.exact_view(start=start_ix)

  // scheme's first byte must be an ascii letter
  guard !bytes.is_empty() && bytes.unsafe_get(0).to_char().is_ascii_alphabetic() else {
    return None
  }

  let mut i = 1

  while i < bytes.length() {
    let c = bytes.unsafe_get(i)
    i += 1
    guard c.is_ascii_alphanumeric() ||
      c == b'.' ||
      c == b'-' ||
      c == b'+' ||
      c == b':' else {
      return None
    }
    if c == b':' {
      break
    }
  }

  // scheme length must be between 2 and 32 characters long. scheme
  // must be followed by colon
  guard i >= 3 && i <= 33 else { return None }

  while i < bytes.length() {
    let c = bytes.unsafe_get(i)
    guard c != b'>' else {
      return Some(
        (
          start_ix + i + 1,
          @utf8.decode_lossy(text.exact_view(start=start_ix, end=start_ix + i)),
        ),
      )
    }
    guard !((c.to_int() >= 0x00 && c.to_int() <= 0x20) || c == b'<') else {
      return None
    }
    i += 1
  }

  None
}

///|
/// Returns (next_byte_offset, email)
fn scan_email(text : BytesView, start_ix : Int) -> (Int, String)? {
  // using a regex library would be convenient, but doing it by hand is not too bad
  let bytes = text.exact_view(start=start_ix)
  let mut i = 0

  while i < bytes.length() {
    let c = bytes.unsafe_get(i)
    i += 1
    if c.is_ascii_alphanumeric() {
      ()
    } else {
      let is_special = c == b'.' ||
        c == b'!' ||
        c == b'#' ||
        c == b'$' ||
        c == b'%' ||
        c == b'&' ||
        c == b'\'' ||
        c == b'*' ||
        c == b'+' ||
        c == b'/' ||
        c == b'=' ||
        c == b'?' ||
        c == b'^' ||
        c == b'_' ||
        c == b'`' ||
        c == b'{' ||
        c == b'|' ||
        c == b'}' ||
        c == b'~' ||
        c == b'-'
      if is_special {
        ()
      } else if c == b'@' && i > 1 {
        break
      } else {
        return None
      }
    }
  }

  let mut label_ix = i
  while true {
    let label_start_ix = label_ix
    let mut fresh_label = true

    while label_ix < bytes.length() {
      let c = bytes.unsafe_get(label_ix)
      if c.is_ascii_alphanumeric() {
        ()
      } else if c == b'-' && fresh_label {
        return None
      } else if c == b'-' {
        ()
      } else {
        break
      }
      fresh_label = false
      label_ix += 1
    }

    let too_long = label_ix - label_start_ix > 63
    let ends_in_dash = bytes.unsafe_get(label_ix - 1) == b'-'
    guard !(label_ix == label_start_ix || too_long || ends_in_dash) else {
      return None
    }

    let has_dot = bytes.length() > label_ix &&
      bytes.unsafe_get(label_ix) == b'.'
    guard has_dot else {
      i = label_ix
      break
    }
    label_ix += 1
  }

  let has_gt = bytes.length() > i && bytes.unsafe_get(i) == b'>'
  guard has_gt else { return None }

  Some(
    (
      start_ix + i + 1,
      @utf8.decode_lossy(text.exact_view(start=start_ix, end=start_ix + i)),
    ),
  )
}

///|
/// Scan comment, declaration, or CDATA section, with initial "<!" already consumed.
/// Returns byte offset on match.
fn scan_inline_html_comment(
  bytes : BytesView,
  ix : Int,
  scan_guard : HtmlScanGuard,
) -> Int? {
  let mut ix = ix
  guard ix < bytes.length() else { return None }
  let c = bytes.unsafe_get(ix)
  ix += 1
  if c == b'-' && ix > scan_guard.comment {
    // HTML comment needs two hyphens after the !.
    guard ix < bytes.length() && bytes.unsafe_get(ix) == b'-' else {
      return None
    }
    // Yes, we're intentionally going backwards.
    ix -= 1

    while true {
      match find_byte(bytes, ix, b'-') {
        Some(off) => {
          ix = off + 1
          scan_guard.comment = ix
          let is_close = bytes.length() > ix &&
            bytes.unsafe_get(ix) == b'-' &&
            bytes.length() > ix + 1 &&
            bytes.unsafe_get(ix + 1) == b'>'
          guard !is_close else { return Some(ix + 2) }
        }
        None => break
      }
    }
    None
  } else {
    let is_cdata = c == b'[' &&
      ix < bytes.length() &&
      ix + 6 <= bytes.length() &&
      bytes.exact_view(start=ix, end=ix + 6).has_prefix(b"CDATA[".exact_view()) &&
      ix > scan_guard.cdata
    if is_cdata {
      ix += 6 // "CDATA[".len()
      match find_byte(bytes, ix, b']') {
        Some(off) => ix = off
        None => ix = bytes.length()
      }
      let close_brackets = scan_ch_repeat(bytes.exact_view(start=ix), b']')
      ix += close_brackets

      guard close_brackets != 0 &&
        bytes.length() > ix &&
        bytes.unsafe_get(ix) == b'>' else {
        scan_guard.cdata = ix
        None
      }
      Some(ix + 1)
    } else {
      let is_decl = c.to_char().is_ascii_alphabetic() &&
        ix > scan_guard.declaration
      guard is_decl else { None }
      match find_byte(bytes, ix, b'>') {
        Some(off) => ix = off
        None => ix = bytes.length()
      }
      guard bytes.length() > ix && bytes.unsafe_get(ix) == b'>' else {
        scan_guard.declaration = ix
        None
      }
      Some(ix + 1)
    }
  }
}

///|
fn find_byte(bytes : BytesView, from : Int, b : Byte) -> Int? {
  let mut i = from
  while i < bytes.length() {
    guard bytes.unsafe_get(i) != b else { return Some(i) }
    i += 1
  }
  None
}

///|
/// Scan processing directive, with initial "<?" already consumed.
/// Returns the next byte offset on success.
fn scan_inline_html_processing(
  bytes : BytesView,
  ix : Int,
  scan_guard : HtmlScanGuard,
) -> Int? {
  let mut ix = ix
  guard ix > scan_guard.processing else { return None }
  while true {
    match find_byte(bytes, ix, b'?') {
      Some(off) => {
        ix = off + 1
        guard !(bytes.length() > ix && bytes.unsafe_get(ix) == b'>') else {
          return Some(ix + 1)
        }
      }
      None => break
    }
  }
  scan_guard.processing = ix
  None
}

// A struct containing information on the reachability of certain inline HTML
// elements.

///|
struct HtmlScanGuard {
  mut cdata : Int
  mut processing : Int
  mut declaration : Int
  mut comment : Int
}

///|
fn html_scan_guard_default() -> HtmlScanGuard {
  { cdata: 0, processing: 0, declaration: 0, comment: 0, }
}

///|
fn bytes_find_byte(bytes : Bytes, from : Int, to : Int, b : Byte) -> Int? {
  let mut i = from
  while i < to {
    guard bytes.unsafe_get(i) != b else { return Some(i - from) }
    i += 1
  }
  None
}

///|
fn bytes_contains_str(
  bytes : Bytes,
  from : Int,
  to : Int,
  needle : String,
) -> Bool {
  let nb = @utf8.encode(needle)
  guard nb.length() != 0 else { return true }
  let mut i = from
  while i + nb.length() <= to {
    guard !bytes.exact_view(start=i, end=i + nb.length()).equal_to_bytes(nb) else {
      return true
    }
    i += 1
  }
  false
}

///|
fn bytesview_iter_rev_position(bytes : BytesView, f : (Byte) -> Bool) -> Int? {
  let mut i = bytes.length()
  while i > 0 {
    i -= 1
    guard !f(bytes.unsafe_get(i)) else { return Some(i + 1) }
  }
  None
}
