//! Link label parsing and matching.

///|
/// Assumes the opening bracket has already been scanned.
/// The line break handler determines what happens when a linebreak
/// is found. It is passed the bytes following the line break and
/// either returns `Some(k)`, where `k` is the number of bytes to skip,
/// or `None` to abort parsing the label.
/// Returns the number of bytes read (including closing bracket) and label on success.
fn scan_link_label_rest(
  text : BytesView,
  start : Int,
  linebreak_handler : ((BytesView) -> Int?)?,
  is_in_table : Bool,
) -> (Int, String)? {
  let bytes = text.exact_view(start~)
  let mut ix = 0
  let mut only_white_space = true
  let mut codepoints = 0
  // no worries, doesn't allocate until we push things onto it
  let label = StringBuilder()
  let mut mark = 0

  while true {
    guard codepoints < 1000 else { return None }
    guard ix < bytes.length() else { return None }
    let b = bytes.unsafe_get(ix)
    guard b != b'[' else { return None }
    if b == b']' {
      break
    }
    let is_pipe_escape = b == b'|' &&
      is_in_table &&
      ix != 0 &&
      bytes.unsafe_get(ix - 1) == b'\\'
    let is_table_pipe = b == b'\\' &&
      is_in_table &&
      ix + 1 < bytes.length() &&
      bytes.unsafe_get(ix + 1) == b'|'
    if is_pipe_escape {
      // only way to reach this spot is to have `\\|` (even number of `\` before `|`)
      write_range(label, bytes, mark, ix - 1)
      label.write_string("|")
      ix += 1
      only_white_space = false
      mark = ix
    } else if is_table_pipe {
      // only way to reach this spot is to have `\|` (odd number of `\` before `|`)
      write_range(label, bytes, mark, ix)
      label.write_string("|")
      ix += 2
      codepoints += 1
      only_white_space = false
      mark = ix
    } else if b == b'\x00' {
      write_range(label, bytes, mark, ix)
      label.write_string("\u{fffd}")
      ix += 1
      codepoints += 1
      only_white_space = false
      mark = ix
    } else {
      let is_backslash_escape = b == b'\\' &&
        ix + 1 < bytes.length() &&
        is_ascii_punctuation(bytes.unsafe_get(ix + 1).to_int())
      if is_backslash_escape {
        ix += 2
        codepoints += 2
        only_white_space = false
      } else if b.to_char().is_ascii_whitespace() {
        // normalize labels by collapsing whitespaces, including linebreaks
        let mut whitespaces = 0
        let mut linebreaks = 0
        let whitespace_start = ix

        while ix < bytes.length() &&
              bytes.unsafe_get(ix).to_char().is_ascii_whitespace() {
          match scan_eol(bytes.exact_view(start=ix)) {
            Some(eol_bytes) => {
              linebreaks += 1
              guard linebreaks <= 1 else { return None }
              ix += eol_bytes
              guard linebreak_handler is Some(handler) else { return None }
              guard handler(bytes.exact_view(start=ix)) is Some(skip) else {
                return None
              }
              ix += skip
              whitespaces += 2 // indicate that we need to replace
            }
            None => {
              whitespaces += if bytes.unsafe_get(ix) == b' ' { 1 } else { 2 }
              ix += 1
            }
          }
        }
        if whitespaces > 1 {
          write_range(label, bytes, mark, whitespace_start)
          label.write_string(" ")
          mark = ix
          codepoints += ix - whitespace_start
        } else {
          codepoints += 1
        }
      } else {
        only_white_space = false
        ix += 1
        if (b.to_int() & 0b1000_0000) != 0 {
          codepoints += 1
        }
      }
    }
  }

  if only_white_space {
    None
  } else {
    let label_str = if mark == 0 {
      trim_ascii_ws(@utf8.decode_lossy(bytes.exact_view(start=0, end=ix)))
    } else {
      write_range(label, bytes, mark, ix)
      let s = label.to_string()
      trim_ascii_ws(s)
    }
    Some((ix + 1, label_str))
  }
}

///|
fn trim_ascii_ws(s : String) -> String {
  s.trim(chars=" \r\n\t").to_owned()
}
