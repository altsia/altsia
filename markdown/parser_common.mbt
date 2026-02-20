///|
type BlockRule = (BlockState, Int) -> Int?

///|
type InlineRule = (InlineState, Int) -> (MdToken, Int)?

///|
fn md_char_at(source : String, i : Int) -> Char {
  source.get_char(i).unwrap()
}

///|
fn md_has_prefix_at(source : String, start : Int, prefix : String) -> Bool {
  let end_index = start + prefix.length()
  if start < 0 || end_index > source.length() {
    return false
  }
  source.unsafe_substring(start~, end=end_index) == prefix
}

///|
fn md_find_char_from(source : String, target : Char, start : Int) -> Int? {
  let mut i = start
  let len = source.length()
  while i < len {
    if md_char_at(source, i) == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn md_find_substring_from(
  source : String,
  pattern : String,
  start : Int,
) -> Int? {
  if pattern.is_empty() {
    return Some(start)
  }
  let max_start = source.length() - pattern.length()
  let mut i = start
  while i <= max_start {
    if md_has_prefix_at(source, i, pattern) {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn md_is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn md_is_html_name_char(ch : Char) -> Bool {
  md_is_ascii_letter(ch) ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == ':'
}

///|
fn md_skip_spaces_in_range(
  source : String,
  start : Int,
  end_exclusive : Int,
) -> Int {
  let mut i = start
  while i < end_exclusive && md_is_space(md_char_at(source, i)) {
    i += 1
  }
  i
}

///|
fn md_read_html_name(
  source : String,
  start : Int,
  end_exclusive : Int,
) -> (String, Int)? {
  if start >= end_exclusive || !md_is_ascii_letter(md_char_at(source, start)) {
    return None
  }
  let mut i = start + 1
  while i < end_exclusive && md_is_html_name_char(md_char_at(source, i)) {
    i += 1
  }
  Some((source.unsafe_substring(start~, end=i), i))
}

///|
fn md_parse_html_open_line(
  line : String,
) -> (String, Array[(String, String)], Bool)? {
  let source = md_trim_edges(line)
  let len = source.length()
  if len < 3 ||
    md_char_at(source, 0) != '<' ||
    md_char_at(source, len - 1) != '>' {
    return None
  }
  let last = len - 1
  let mut i = 1
  let first = md_char_at(source, i)
  if first == '/' || first == '!' || first == '?' {
    return None
  }
  guard md_read_html_name(source, i, last) is Some((tag, next_i)) else {
    return None
  }
  i = next_i
  let attrs : Array[(String, String)] = []
  let mut self_close = false
  while i < last {
    i = md_skip_spaces_in_range(source, i, last)
    if i >= last {
      break
    }
    if md_char_at(source, i) == '/' {
      if i + 1 == last {
        self_close = true
        i += 1
        break
      }
      return None
    }
    guard md_read_html_name(source, i, last) is Some((attr_name, attr_end)) else {
      return None
    }
    i = md_skip_spaces_in_range(source, attr_end, last)
    let mut attr_value = "true"
    if i < last && md_char_at(source, i) == '=' {
      i += 1
      i = md_skip_spaces_in_range(source, i, last)
      if i >= last {
        attr_value = ""
      } else {
        let ch = md_char_at(source, i)
        if ch == '"' || ch == '\'' {
          let quote = ch
          let value_start = i + 1
          i += 1
          while i < last && md_char_at(source, i) != quote {
            i += 1
          }
          if i >= last {
            return None
          }
          attr_value = source.unsafe_substring(start=value_start, end=i)
          i += 1
        } else {
          let value_start = i
          while i < last {
            let current = md_char_at(source, i)
            if md_is_space(current) || (current == '/' && i + 1 == last) {
              break
            }
            i += 1
          }
          attr_value = source.unsafe_substring(start=value_start, end=i)
        }
      }
    }
    attrs.push((attr_name, attr_value))
  }
  Some((tag, attrs, self_close))
}

///|
fn md_parse_html_close_line(line : String) -> String? {
  let source = md_trim_edges(line)
  let len = source.length()
  if len < 4 ||
    !md_has_prefix_at(source, 0, "</") ||
    md_char_at(source, len - 1) != '>' {
    return None
  }
  let last = len - 1
  let mut i = md_skip_spaces_in_range(source, 2, last)
  guard md_read_html_name(source, i, last) is Some((tag, next_i)) else {
    return None
  }
  i = md_skip_spaces_in_range(source, next_i, last)
  if i != last {
    return None
  }
  Some(tag)
}

///|
fn md_strip_trailing_cr(line : String) -> String {
  if line.is_empty() {
    return line
  }
  if md_char_at(line, line.length() - 1) == '\r' {
    return line.unsafe_substring(start=0, end=line.length() - 1)
  }
  line
}

///|
fn md_is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn md_trim_edges(source : String) -> String {
  let len = source.length()
  let mut left = 0
  let mut right = len
  while left < right && md_is_space(md_char_at(source, left)) {
    left += 1
  }
  while right > left && md_is_space(md_char_at(source, right - 1)) {
    right -= 1
  }
  source.unsafe_substring(start=left, end=right)
}

///|
fn md_ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + 32)
  } else {
    ch
  }
}

///|
fn md_normalize_reference_label(label : String) -> String {
  let trimmed = md_trim_edges(label)
  let mut normalized = ""
  let mut in_space = false
  for ch in trimmed.iter() {
    if md_is_space(ch) {
      if !in_space {
        normalized = normalized + " "
        in_space = true
      }
    } else {
      normalized = normalized + md_ascii_lower_char(ch).to_string()
      in_space = false
    }
  }
  normalized
}

///|
fn md_extract_link_destination(raw : String) -> String {
  let trimmed = md_trim_edges(raw)
  if trimmed.is_empty() {
    return ""
  }
  if md_char_at(trimmed, 0) == '<' {
    match md_find_char_from(trimmed, '>', 1) {
      Some(end) => trimmed.unsafe_substring(start=1, end~)
      None => trimmed
    }
  } else {
    let mut i = 0
    while i < trimmed.length() && !md_is_space(md_char_at(trimmed, i)) {
      i += 1
    }
    trimmed.unsafe_substring(start=0, end=i)
  }
}

///|
fn md_parse_link_reference_definition(
  line : String,
) -> (String, String, String)? {
  let indent = md_leading_spaces_upto(line, 3)
  if indent >= line.length() || md_char_at(line, indent) != '[' {
    return None
  }
  guard md_find_char_from(line, ']', indent + 1) is Some(close_bracket) else {
    return None
  }
  let colon_index = close_bracket + 1
  if colon_index >= line.length() || md_char_at(line, colon_index) != ':' {
    return None
  }
  let raw_label = line.unsafe_substring(start=indent + 1, end=close_bracket)
  let label = md_trim_edges(raw_label)
  if label.is_empty() || md_has_prefix_at(label, 0, "^") {
    return None
  }
  let key = md_normalize_reference_label(label)
  let href_raw = line.unsafe_substring(start=colon_index + 1, end=line.length())
  let href = md_extract_link_destination(href_raw)
  if href.is_empty() {
    return None
  }
  Some((label, key, href))
}

///|
fn md_parse_footnote_definition_start(line : String) -> (String, String)? {
  let indent = md_leading_spaces_upto(line, 3)
  if indent + 2 >= line.length() || !md_has_prefix_at(line, indent, "[^") {
    return None
  }
  guard md_find_char_from(line, ']', indent + 2) is Some(close_bracket) else {
    return None
  }
  let colon_index = close_bracket + 1
  if colon_index >= line.length() || md_char_at(line, colon_index) != ':' {
    return None
  }
  let raw_label = line.unsafe_substring(start=indent + 2, end=close_bracket)
  let label = md_normalize_reference_label(raw_label)
  if label.is_empty() {
    return None
  }
  let rest = line.unsafe_substring(start=colon_index + 1, end=line.length())
  Some((label, md_trim_edges(rest)))
}

///|
fn md_is_footnote_continuation_line(line : String) -> Bool {
  if line.is_empty() {
    return true
  }
  md_has_prefix_at(line, 0, "    ") ||
  md_has_prefix_at(line, 0, "\t") ||
  md_has_prefix_at(line, 0, "  ")
}

///|
fn md_strip_footnote_continuation_indent(line : String) -> String {
  if md_has_prefix_at(line, 0, "    ") {
    line.unsafe_substring(start=4, end=line.length())
  } else if md_has_prefix_at(line, 0, "\t") {
    line.unsafe_substring(start=1, end=line.length())
  } else if md_has_prefix_at(line, 0, "  ") {
    line.unsafe_substring(start=2, end=line.length())
  } else {
    line
  }
}

///|
fn md_upsert_link_reference(
  defs : Map[String, MdLinkReference],
  label : String,
  key : String,
  href : String,
) -> Unit {
  defs[key] = MdLinkReference::{ label, href }
}

///|
fn md_upsert_footnote_lines(
  defs : Array[(String, Array[String])],
  label : String,
  lines : Array[String],
) -> Unit {
  for i in 0..<defs.length() {
    if defs[i].0 == label {
      defs[i] = (label, lines)
      return
    }
  }
  defs.push((label, lines))
}

///|
fn md_extract_definitions(
  lines : Array[String],
  start_line : Int,
) -> (
  Array[String],
  Map[String, MdLinkReference],
  Array[(String, Array[String])],
) {
  let content_lines : Array[String] = []
  let link_references : Map[String, MdLinkReference] = Map::new()
  let footnote_lines : Array[(String, Array[String])] = []
  let mut i = start_line
  while i < lines.length() {
    match md_parse_link_reference_definition(lines[i]) {
      Some((label, key, href)) => {
        md_upsert_link_reference(link_references, label, key, href)
        content_lines.push("")
        i += 1
        continue
      }
      None => ()
    }
    match md_parse_footnote_definition_start(lines[i]) {
      Some((label, first_line)) => {
        let body_lines : Array[String] = [first_line]
        i += 1
        while i < lines.length() {
          if !md_is_footnote_continuation_line(lines[i]) {
            break
          }
          body_lines.push(md_strip_footnote_continuation_indent(lines[i]))
          i += 1
        }
        md_upsert_footnote_lines(footnote_lines, label, body_lines)
        content_lines.push("")
        continue
      }
      None => ()
    }
    content_lines.push(lines[i])
    i += 1
  }
  (content_lines, link_references, footnote_lines)
}

///|
fn md_is_blank_line(line : String) -> Bool {
  if line.is_empty() {
    return true
  }
  line.iter().all(md_is_space)
}

///|
fn md_is_front_matter_open(line : String) -> Bool {
  md_trim_edges(line) == "---"
}

///|
fn md_is_front_matter_close(line : String) -> Bool {
  let trimmed = md_trim_edges(line)
  trimmed == "---" || trimmed == "..."
}

///|
fn md_skip_leading_blank_lines(lines : Array[String]) -> Int {
  let mut i = 0
  while i < lines.length() && md_is_blank_line(lines[i]) {
    i += 1
  }
  i
}

///|
fn try_consume_front_matter(lines : Array[String]) -> (MdToken, Int)? {
  if lines.is_empty() {
    return None
  }
  let start = md_skip_leading_blank_lines(lines)
  if start >= lines.length() || !md_is_front_matter_open(lines[start]) {
    return None
  }
  let body_lines : Array[String] = []
  let mut i = start + 1
  while i < lines.length() {
    if md_is_front_matter_close(lines[i]) {
      return Some(
        (
          make_token("front_matter", "yaml", content=body_lines.join("\n")),
          i + 1,
        ),
      )
    }
    body_lines.push(lines[i])
    i += 1
  }
  None
}

///|
fn md_split_first_colon(line : String) -> (String, String)? {
  guard md_find_char_from(line, ':', 0) is Some(split_at) else { return None }
  let key = md_trim_edges(line.unsafe_substring(start=0, end=split_at))
  if key.is_empty() {
    return None
  }
  let value = md_trim_edges(
    line.unsafe_substring(start=split_at + 1, end=line.length()),
  )
  Some((key, value))
}

///|
fn parse_metadata_from_front_matter_content(
  content : String,
) -> Array[MdMetadataItem] {
  let items : Array[MdMetadataItem] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if md_trim_edges(line).is_empty() {
      continue
    }
    match md_split_first_colon(line) {
      Some((key, value)) =>
        items.push(MdMetadataItem::{
          key,
          value,
          value_tokens: parse_inline_tokens(value),
        })
      None => ()
    }
  }
  items
}

///|
fn md_leading_spaces_upto(line : String, limit : Int) -> Int {
  let mut i = 0
  let len = line.length()
  while i < len && i < limit && md_char_at(line, i) == ' ' {
    i += 1
  }
  i
}
