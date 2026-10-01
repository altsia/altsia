//! Delimiter-run flanking rules, heading attribute blocks, and the special
//! byte lookup table.

///|
/// A `~` delimiter run may be intraword when it is a `~~` strikethrough
/// or a subscript `~`.
fn is_intraword_tilde(delim : Byte, run_len : Int, options : Options) -> Bool {
  delim == b'~' && (run_len > 1 || options.contains(enable_subscript()))
}

///|
/// Determines whether the delimiter run starting at given index is
/// left-flanking, as defined by the commonmark spec (and isn't intraword
/// for _ delims).
fn delim_run_can_open(
  s : Bytes,
  start : Int,
  ix : Int,
  run_len : Int,
  mode : TableParseMode,
  options : Options,
) -> Bool {
  let suffix = s.exact_view(start=ix)
  guard decode_char(s, ix + run_len) is Some(next_char) else { return false }
  guard !next_char.is_whitespace() else { return false }
  let delim = suffix.unsafe_get(0)
  // `^` with punctuation content (e.g. `^+^`) requires a preceding alphanumeric
  // or delimiter character (e.g. `H^+^`, `NH~4~^+^`).
  if delim == b'^' && is_punctuation(next_char.to_int()) {
    guard ix - start != 0 else { return false }
    if options.contains(enable_superscript()) {
      if decode_char(s, prev_char_ix(s, ix)) is Some(prev_char) {
        if is_alphanumeric_char(prev_char) ||
          prev_char == '~' ||
          prev_char == '^' {
          return true
        }
      }
    }
    // Punctuation content without qualifying predecessor -- don't open
    return false
  }
  guard decode_char(s, prev_char_ix(s, ix)) is Some(prev_char) else {
    return true
  }
  let in_table = mode is Active
  if in_table {
    guard !ends_with_pipe(s, ix) else { return true }
    guard next_char != '|' else { return false }
  }
  let is_cjk_delim = options.contains(enable_cjk_friendly_emphasis()) &&
    is_cjk_friendly_delim(delim, run_len, options)
  guard !is_cjk_delim else {
    return cjk_friendly_delim_run_flanking(
        prev_char,
        () => decode_char(s, prev_char_ix(s, prev_char_ix(s, ix))),
        next_char,
        delim,
      ).can_open
  }
  // `*`, `~~`, and `^` can be intraword, `~` can only be interword if it's subscript
  guard !(delim == b'*' && !is_punctuation(next_char.to_int())) else {
    return true
  }
  // `^` with non-punctuation content can open intraword
  guard delim != b'^' else { return true }
  guard !(delim == b'~' && run_len > 1) else { return true }
  guard !(delim == b'=' && run_len == 2) else { return true }
  let can_open_tilde = is_intraword_tilde(delim, run_len, options) &&
    !is_punctuation(next_char.to_int())
  guard !can_open_tilde else { return true }

  prev_char.is_whitespace() ||
  (
    is_punctuation(prev_char.to_int()) &&
    (delim != b'\'' || !(prev_char == ']' || prev_char == ')'))
  )
}

///|
/// Determines whether the delimiter run starting at given index is
/// right-flanking, as defined by the commonmark spec.
fn delim_run_can_close(
  s : Bytes,
  start : Int,
  ix : Int,
  run_len : Int,
  mode : TableParseMode,
  options : Options,
) -> Bool {
  guard ix - start != 0 else { return false }
  guard decode_char(s, prev_char_ix(s, ix)) is Some(prev_char) else {
    return false
  }
  guard !prev_char.is_whitespace() else { return false }
  guard decode_char(s, ix + run_len) is Some(next_char) else { return true }
  let in_table = mode is Active
  if in_table {
    guard !ends_with_pipe(s, ix) else { return false }
    guard next_char != '|' else { return true }
  }
  let delim = s.exact_view(start=ix).unsafe_get(0)
  let is_cjk_delim = options.contains(enable_cjk_friendly_emphasis()) &&
    is_cjk_friendly_delim(delim, run_len, options)
  guard !is_cjk_delim else {
    return cjk_friendly_delim_run_flanking(
        prev_char,
        () => decode_char(s, prev_char_ix(s, prev_char_ix(s, ix))),
        next_char,
        delim,
      ).can_close
  }
  // `*`, `~~`, and `^` can be intraword, `~` can only be interword if it's subscript
  let is_intraword = (
      delim == b'*' ||
      is_intraword_tilde(delim, run_len, options) ||
      (delim == b'=' && run_len == 2)
    ) &&
    !is_punctuation(prev_char.to_int())
  guard !is_intraword else { return true }
  guard !(delim == b'^' && !is_punctuation(prev_char.to_int())) else {
    return true
  }
  guard !is_intraword_tilde(delim, run_len, options) else { return true }

  next_char.is_whitespace() || is_punctuation(next_char.to_int())
}

///|
fn is_cjk_friendly_delim(
  delim : Byte,
  run_len : Int,
  options : Options,
) -> Bool {
  // two-tilde strikethrough, subscripts, superscript, and highlighter don't use flanking
  delim == b'*' ||
  delim == b'_' ||
  (delim == b'~' && run_len == 1 && !options.contains(enable_subscript()))
}

///|
priv struct CjkFriendlyDelimiterRunFlanking {
  can_open : Bool
  can_close : Bool
}

///|
fn cjk_friendly_delim_run_flanking(
  prev_char : Char,
  get_prev_prev_char : () -> Char?,
  next_char : Char,
  delim : Byte,
) -> CjkFriendlyDelimiterRunFlanking {
  if delim == b'_' || delim == b'~' {
    return cjk_friendly_underscore_delim_run_flanking(
      prev_char, get_prev_prev_char, next_char,
    )
  }

  let prev_sequence = classify_preceding_cjk_friendly_sequence(
    prev_char, get_prev_prev_char,
  )
  let before_cjk_or_ivs = prev_sequence.is_cjk ||
    prev_sequence.is_ideographic_variation_selector
  let before_space_or_punctuation = prev_char.is_whitespace() ||
    prev_sequence.is_punctuation

  let after_cjk = next_char.is_cjk_character()
  let after_punctuation = is_punctuation(next_char.to_int())
  let after_space_or_punctuation = next_char.is_whitespace() ||
    after_punctuation

  let open = !next_char.is_whitespace() &&
    (
      !after_punctuation ||
      before_space_or_punctuation ||
      before_cjk_or_ivs ||
      after_cjk ||
      next_char == '*' ||
      next_char == '_'
    )
  let close = !prev_char.is_whitespace() &&
    (
      !prev_sequence.is_punctuation ||
      after_space_or_punctuation ||
      prev_sequence.is_cjk ||
      after_cjk ||
      prev_char == '*' ||
      prev_char == '_'
    )

  { can_open: open, can_close: close, }
}

///|
fn cjk_friendly_underscore_delim_run_flanking(
  prev_char : Char,
  get_prev_prev_char : () -> Char?,
  next_char : Char,
) -> CjkFriendlyDelimiterRunFlanking {
  let before_punctuation = is_preceding_cjk_friendly_punctuation(
    prev_char, get_prev_prev_char,
  )
  let before_space_or_punctuation = prev_char.is_whitespace() ||
    before_punctuation

  let after_punctuation = is_punctuation(next_char.to_int())
  let after_space_or_punctuation = next_char.is_whitespace() ||
    after_punctuation

  let open = !next_char.is_whitespace() &&
    (
      !after_punctuation ||
      before_space_or_punctuation ||
      next_char == '*' ||
      next_char == '_'
    )
  let close = !prev_char.is_whitespace() &&
    (
      !before_punctuation ||
      after_space_or_punctuation ||
      prev_char == '*' ||
      prev_char == '_'
    )

  {
    can_open: open && (before_space_or_punctuation || !close),
    can_close: close && (after_space_or_punctuation || !open),
  }
}

///|
fn is_alphanumeric_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit()
}

///|
/// Decodes the char starting at byte offset `ix`. Returns None if out of range.
fn decode_char(s : Bytes, ix : Int) -> Char? {
  guard ix < s.length() else { return None }
  let b0 = s.unsafe_get(ix).to_int()
  let len = if b0 < 0x80 {
    1
  } else if b0 < 0xE0 {
    2
  } else if b0 < 0xF0 {
    3
  } else {
    4
  }
  guard ix + len <= s.length() else { return None }
  let sub = s.exact_view(start=ix, end=ix + len)
  @utf8.decode_lossy(sub).get_char(0)
}

///|
/// Returns the byte index of the char before byte offset `ix`.
fn prev_char_ix(s : Bytes, ix : Int) -> Int {
  guard ix > 0 else { return 0 }
  let mut i = ix - 1
  while i > 0 && (s.unsafe_get(i).to_int() & 0xC0) == 0x80 {
    i -= 1
  }
  i
}

///|
fn ends_with_pipe(s : Bytes, ix : Int) -> Bool {
  let prefix = s.exact_view(start=0, end=ix)
  prefix.has_suffix(b"|".exact_view()) && !prefix.has_suffix(b"\\|".exact_view())
}

///|
fn special_bytes(options : Options) -> Array[Bool] {
  let bytes : Array[Bool] = Array::make(256, false)
  let standard_bytes = [
    b'\n', b'\r', b'*', b'_', b'&', b'\\', b'[', b']', b'<', b'!', b'`', b'\x00',
  ]

  for byte in standard_bytes {
    bytes[byte.to_int()] = true
  }
  if options.contains(enable_tables()) {
    bytes[b'|'.to_int()] = true
  }
  if options.contains(enable_strikethrough()) ||
    options.contains(enable_subscript()) {
    bytes[b'~'.to_int()] = true
  }
  if options.contains(enable_superscript()) {
    bytes[b'^'.to_int()] = true
  }
  if options.contains(enable_highlight()) {
    bytes[b'='.to_int()] = true
  }
  if options.contains(enable_math()) {
    bytes[b'$'.to_int()] = true
    bytes[b'{'.to_int()] = true
    bytes[b'}'.to_int()] = true
  }
  if options.contains(enable_smart_punctuation()) {
    for byte in [b'.', b'-', b'"', b'\''] {
      bytes[byte.to_int()] = true
    }
  }

  bytes
}

///|
/// Computes the number of header columns in a table line.
fn count_header_cols(
  bytes : BytesView,
  pipes : Int,
  start : Int,
  last_pipe_ix : Int,
) -> Int {
  let mut pipes = pipes
  let mut start = start
  // was first pipe preceded by whitespace? if so, subtract one
  start += scan_whitespace_no_nl(bytes.exact_view(start~))
  if bytes.length() > start && bytes.unsafe_get(start) == b'|' {
    pipes -= 1
  }

  // was last pipe followed by whitespace? if so, sub one
  if scan_blank_line(bytes.exact_view(start=last_pipe_ix + 1)) is Some(_) {
    pipes
  } else {
    pipes + 1
  }
}

///|
/// Split the usual heading content range and the content inside the trailing attribute block.
fn extract_attribute_block_content_from_header_text(
  heading : BytesView,
) -> (Int, (Int, Int)?) {
  let heading_len = heading.length()
  let mut ix = heading_len
  ix -= scan_rev_while(heading, b => {
    b == b'\n' || b == b'\r' || b == b' ' || b == b'\t'
  })
  guard ix != 0 else { return (heading_len, None) }

  let attr_block_close = ix - 1
  if heading.length() <= attr_block_close ||
    heading.unsafe_get(attr_block_close) != b'}' {
    // The last character is not `}`. No attribute blocks found.
    return (heading_len, None)
  }
  // move cursor before the closing right brace (`}`)
  ix -= 1

  ix -= scan_rev_while(heading.exact_view(start=0, end=ix), b => {
    !(b == b'{' ||
    b == b'}' ||
    b == b'<' ||
    b == b'>' ||
    b == b'\\' ||
    b == b'\n' ||
    b == b'\r')
  })
  if ix == 0 {
    // `{` is not found. No attribute blocks available.
    return (heading_len, None)
  }
  let attr_block_open = ix - 1
  if heading.unsafe_get(attr_block_open) != b'{' {
    // `{` is not found. No attribute blocks available.
    return (heading_len, None)
  }

  (attr_block_open, Some((ix, attr_block_close)))
}

///|
/// Parses an attribute block content, such as `.class1 #id .class2`.
fn parse_inside_attribute_block(
  inside_attr_block : String,
) -> HeadingAttributes? {
  let mut id : String? = None
  let classes : Array[String] = []
  let attrs : Array[(String, String?)] = []

  for attr in split_ascii_whitespace(inside_attr_block) {
    let attr_bytes = @utf8.encode(attr)
    if attr_bytes.length() > 1 {
      let first_byte = attr_bytes.unsafe_get(0)
      if first_byte == b'#' {
        id = Some(
          replace_nuls(
            @utf8.decode_lossy(
              attr_bytes.exact_view(start=1, end=attr_bytes.length()),
            ),
          ),
        )
      } else if first_byte == b'.' {
        classes.push(
          replace_nuls(
            @utf8.decode_lossy(
              attr_bytes.exact_view(start=1, end=attr_bytes.length()),
            ),
          ),
        )
      } else {
        match attr.split_once("=") {
          Some((key, value)) =>
            attrs.push(
              (
                replace_nuls(key.to_owned()),
                Some(replace_nuls(value.to_owned())),
              ),
            )
          None => attrs.push((replace_nuls(attr), None))
        }
      }
    }
  }

  Some(HeadingAttributes::{ id, classes, attrs, })
}

///|
fn split_ascii_whitespace(s : String) -> Array[String] {
  let bytes = @utf8.encode(s)
  let result : Array[String] = []
  let mut start = -1
  for i in 0..<=bytes.length() {
    if i < bytes.length() && !bytes.unsafe_get(i).is_ascii_whitespace_std() {
      if start < 0 {
        start = i
      }
    } else if start >= 0 {
      result.push(@utf8.decode_lossy(bytes.exact_view(start~, end=i)))
      start = -1
    }
  }
  result
}

///|
/// Rust std `u8::is_ascii_whitespace` (used by `str::split_ascii_whitespace`):
/// tab, LF, FF, CR, space — notably NOT vertical tab.
fn Byte::is_ascii_whitespace_std(c : Byte) -> Bool {
  let b = c.to_int()
  b == 0x09 || b == 0x0a || b == 0x0c || b == 0x0d || b == 0x20
}

///|
fn is_active_mode(mode : TableParseMode) -> Bool {
  mode is Active
}

///|
fn is_scan_mode(mode : TableParseMode) -> Bool {
  mode is Scan
}
