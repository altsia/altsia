// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn md_parse_heading_line(line : String) -> (String, String)? {
  let indent = md_leading_spaces_upto(line, 3)
  let len = line.length()
  let mut i = indent
  let mut level = 0
  while i < len && level < 6 && md_char_at(line, i) == '#' {
    level += 1
    i += 1
  }
  if level == 0 {
    return None
  }
  if i >= len || !md_is_space(md_char_at(line, i)) {
    return None
  }
  let body = md_trim_edges(line.unsafe_substring(start=i + 1, end=len))
  Some(("h" + level.to_string(), body))
}

///|
fn md_parse_fence_info(line : String) -> String? {
  let indent = md_leading_spaces_upto(line, 3)
  if !md_has_prefix_at(line, indent, "```") {
    return None
  }
  let body = md_trim_edges(
    line.unsafe_substring(start=indent + 3, end=line.length()),
  )
  Some(body)
}

///|
fn md_is_fence_delimiter(line : String) -> Bool {
  md_parse_fence_info(line) is Some(_)
}

///|
fn md_is_math_fence_delimiter(line : String) -> Bool {
  md_trim_edges(line) == "$$"
}

///|
fn md_parse_single_line_math_block_content(line : String) -> String? {
  let trimmed = md_trim_edges(line)
  let len = trimmed.length()
  if len < 4 || !md_has_prefix_at(trimmed, 0, "$$") {
    return None
  }
  let tail_start = len - 2
  if !md_has_prefix_at(trimmed, tail_start, "$$") {
    return None
  }
  let inner = md_trim_edges(trimmed.unsafe_substring(start=2, end=tail_start))
  if inner.is_empty() {
    return None
  }
  Some(inner)
}

///|
fn md_is_math_block_start(line : String) -> Bool {
  md_is_math_fence_delimiter(line) ||
  md_parse_single_line_math_block_content(line) is Some(_)
}

///|
fn md_strip_blockquote_prefix(line : String) -> String? {
  let indent = md_leading_spaces_upto(line, 3)
  if indent >= line.length() || md_char_at(line, indent) != '>' {
    return None
  }
  let mut start = indent + 1
  if start < line.length() && md_char_at(line, start) == ' ' {
    start += 1
  }
  Some(line.unsafe_substring(start~, end=line.length()))
}

///|
fn md_parse_bullet_item(line : String) -> String? {
  let indent = md_leading_spaces_upto(line, 3)
  if indent + 1 >= line.length() {
    return None
  }
  let marker = md_char_at(line, indent)
  if marker != '-' && marker != '*' && marker != '+' {
    return None
  }
  if !md_is_space(md_char_at(line, indent + 1)) {
    return None
  }
  Some(
    md_trim_edges(line.unsafe_substring(start=indent + 2, end=line.length())),
  )
}

///|
fn md_parse_ordered_item(line : String) -> (String, String)? {
  let indent = md_leading_spaces_upto(line, 3)
  let mut i = indent
  let len = line.length()
  while i < len {
    let ch = md_char_at(line, i)
    if ch >= '0' && ch <= '9' {
      i += 1
      continue
    }
    break
  }
  if i == indent {
    return None
  }
  if i + 1 >= len ||
    md_char_at(line, i) != '.' ||
    !md_is_space(md_char_at(line, i + 1)) {
    return None
  }
  let start_text = line.unsafe_substring(start=indent, end=i)
  let content = md_trim_edges(line.unsafe_substring(start=i + 2, end=len))
  Some((start_text, content))
}

///|
fn md_parse_table_cells(line : String) -> Array[String]? {
  let trimmed = md_trim_edges(line)
  if trimmed.is_empty() || !trimmed.contains("|") {
    return None
  }
  let mut body = trimmed
  if !body.is_empty() && md_char_at(body, 0) == '|' {
    body = body.unsafe_substring(start=1, end=body.length())
  }
  if !body.is_empty() && md_char_at(body, body.length() - 1) == '|' {
    body = body.unsafe_substring(start=0, end=body.length() - 1)
  }
  if body.is_empty() {
    return None
  }
  Some(body.split("|").map(StringView::to_string).map(md_trim_edges).collect())
}

///|
fn md_is_table_delim_cell(cell : String) -> Bool {
  let value = md_trim_edges(cell)
  if value.is_empty() {
    return false
  }
  let mut start = 0
  let mut end_index = value.length()
  if md_char_at(value, start) == ':' {
    start += 1
  }
  if end_index > start && md_char_at(value, end_index - 1) == ':' {
    end_index -= 1
  }
  if end_index - start < 3 {
    return false
  }
  for i in start..<end_index {
    if md_char_at(value, i) != '-' {
      return false
    }
  }
  true
}

///|
fn md_parse_table_delimiter_line(line : String) -> Int? {
  guard md_parse_table_cells(line) is Some(cells) else { return None }
  if cells.is_empty() {
    return None
  }
  for cell in cells {
    if !md_is_table_delim_cell(cell) {
      return None
    }
  }
  Some(cells.length())
}

///|
fn md_is_table_start_with_next(lines : Array[String], line : Int) -> Bool {
  if line + 1 >= lines.length() {
    return false
  }
  guard md_parse_table_cells(lines[line]) is Some(header_cells) else {
    return false
  }
  guard md_parse_table_delimiter_line(lines[line + 1]) is Some(columns) else {
    return false
  }
  header_cells.length() == columns
}

///|
fn md_is_special_block_start(line : String) -> Bool {
  let is_heading = md_parse_heading_line(line) is Some(_)
  let is_fence = md_parse_fence_info(line) is Some(_)
  let is_math_fence = md_is_math_block_start(line)
  let is_blockquote = md_strip_blockquote_prefix(line) is Some(_)
  let is_bullet = md_parse_bullet_item(line) is Some(_)
  let is_ordered = md_parse_ordered_item(line) is Some(_)
  is_heading ||
  is_fence ||
  is_math_fence ||
  is_blockquote ||
  is_bullet ||
  is_ordered
}

///|
fn make_token(
  typ : String,
  tag : String,
  content? : String = "",
  attrs? : Array[(String, String)] = [],
  children? : Array[MdToken] = [],
) -> MdToken {
  { typ, tag, content, attrs, children }
}

///|
fn parse_fence_block(state : BlockState, line : Int) -> Int? {
  guard md_parse_fence_info(state.lines[line]) is Some(info) else {
    return None
  }
  let code_lines : Array[String] = []
  let mut i = line + 1
  while i < state.lines.length() {
    if md_is_fence_delimiter(state.lines[i]) {
      i += 1
      break
    }
    code_lines.push(state.lines[i])
    i += 1
  }
  let attrs = []
  if !info.is_empty() {
    attrs.push(("info", info))
  }
  state.tokens.push(
    make_token("fence", "code", content=code_lines.join("\n"), attrs~),
  )
  Some(i)
}

///|
fn parse_math_block(state : BlockState, line : Int) -> Int? {
  match md_parse_single_line_math_block_content(state.lines[line]) {
    Some(content) => {
      state.tokens.push(
        make_token("math_block", "kd", content~, attrs=[
          ("math_style", "single_line"),
        ]),
      )
      return Some(line + 1)
    }
    None => ()
  }
  if !md_is_math_fence_delimiter(state.lines[line]) {
    return None
  }
  let tex_lines : Array[String] = []
  let mut i = line + 1
  while i < state.lines.length() {
    if md_is_math_fence_delimiter(state.lines[i]) {
      i += 1
      break
    }
    tex_lines.push(state.lines[i])
    i += 1
  }
  state.tokens.push(
    make_token("math_block", "kd", content=tex_lines.join("\n"), attrs=[
      ("math_style", "multi_line"),
    ]),
  )
  Some(i)
}

///|
fn parse_heading_block(state : BlockState, line : Int) -> Int? {
  guard md_parse_heading_line(state.lines[line]) is Some((tag, body)) else {
    return None
  }
  state.tokens.push(
    make_token(
      "heading",
      tag,
      children=parse_inline_tokens_with_context(
        body,
        state.link_references,
        state.footnotes,
      ),
    ),
  )
  Some(line + 1)
}

///|
fn make_table_row_token_with_context(
  cells : Array[String],
  header : Bool,
  link_references : Map[String, MdLinkReference],
  footnotes : Array[MdFootnote],
) -> MdToken {
  let children = []
  for cell in cells {
    let typ = if header { "table_head_cell" } else { "table_cell" }
    let tag = if header { "th" } else { "td" }
    children.push(
      make_token(
        typ,
        tag,
        children=parse_inline_tokens_with_context(
          cell, link_references, footnotes,
        ),
      ),
    )
  }
  let row_typ = if header { "table_head_row" } else { "table_row" }
  make_token(row_typ, "tr", children~)
}

///|
fn parse_table_block(state : BlockState, line : Int) -> Int? {
  if line + 1 >= state.lines.length() {
    return None
  }
  guard md_parse_table_cells(state.lines[line]) is Some(header_cells) else {
    return None
  }
  guard md_parse_table_delimiter_line(state.lines[line + 1]) is Some(columns) else {
    return None
  }
  if header_cells.length() != columns {
    return None
  }
  let rows : Array[MdToken] = [
    make_table_row_token_with_context(
      header_cells,
      true,
      state.link_references,
      state.footnotes,
    ),
  ]
  let mut i = line + 2
  while i < state.lines.length() {
    if md_is_blank_line(state.lines[i]) {
      break
    }
    guard md_parse_table_cells(state.lines[i]) is Some(cells) else { break }
    if cells.length() != columns {
      break
    }
    rows.push(
      make_table_row_token_with_context(
        cells,
        false,
        state.link_references,
        state.footnotes,
      ),
    )
    i += 1
  }
  state.tokens.push(make_token("table", "table", children=rows))
  Some(i)
}

///|
fn parse_blockquote_block(state : BlockState, line : Int) -> Int? {
  guard md_strip_blockquote_prefix(state.lines[line]) is Some(first) else {
    return None
  }
  let inner_lines : Array[String] = [first]
  let mut i = line + 1
  while i < state.lines.length() {
    guard md_strip_blockquote_prefix(state.lines[i]) is Some(content) else {
      break
    }
    inner_lines.push(content)
    i += 1
  }
  state.tokens.push(
    make_token(
      "blockquote",
      "blockquote",
      children=parse_blocks_from_lines(
        inner_lines,
        0,
        state.link_references,
        state.footnotes,
      ),
    ),
  )
  Some(i)
}

///|
fn parse_unordered_list_block(state : BlockState, line : Int) -> Int? {
  guard md_parse_bullet_item(state.lines[line]) is Some(first) else {
    return None
  }
  let items = [first]
  let mut i = line + 1
  while i < state.lines.length() {
    guard md_parse_bullet_item(state.lines[i]) is Some(content) else { break }
    items.push(content)
    i += 1
  }
  let children = []
  for item in items {
    children.push(
      make_token(
        "list_item",
        "li",
        children=parse_inline_tokens_with_context(
          item,
          state.link_references,
          state.footnotes,
        ),
      ),
    )
  }
  state.tokens.push(make_token("bullet_list", "ul", children~))
  Some(i)
}

///|
fn parse_ordered_list_block(state : BlockState, line : Int) -> Int? {
  guard md_parse_ordered_item(state.lines[line]) is Some((start_text, first)) else {
    return None
  }
  let items = [first]
  let mut i = line + 1
  while i < state.lines.length() {
    guard md_parse_ordered_item(state.lines[i]) is Some((_, content)) else {
      break
    }
    items.push(content)
    i += 1
  }
  let item_tokens = []
  for item in items {
    item_tokens.push(
      make_token(
        "list_item",
        "li",
        children=parse_inline_tokens_with_context(
          item,
          state.link_references,
          state.footnotes,
        ),
      ),
    )
  }
  let attrs = [("start", start_text)]
  state.tokens.push(
    make_token("ordered_list", "ol", attrs~, children=item_tokens),
  )
  Some(i)
}

///|
fn parse_html_block(state : BlockState, line : Int) -> Int? {
  guard md_parse_html_open_line(state.lines[line])
    is Some((tag, attrs, self_close)) else {
    return None
  }
  if self_close {
    state.tokens.push(make_token("html_block", tag, attrs~, children=[]))
    return Some(line + 1)
  }
  let body_lines : Array[String] = []
  let mut i = line + 1
  let mut depth = 0
  while i < state.lines.length() {
    match md_parse_html_close_line(state.lines[i]) {
      Some(close_tag) if close_tag == tag => {
        if depth == 0 {
          state.tokens.push(
            make_token(
              "html_block",
              tag,
              attrs~,
              children=parse_blocks_from_lines(
                body_lines,
                0,
                state.link_references,
                state.footnotes,
              ),
            ),
          )
          return Some(i + 1)
        }
        depth -= 1
        body_lines.push(state.lines[i])
        i += 1
        continue
      }
      _ => ()
    }
    match md_parse_html_open_line(state.lines[i]) {
      Some((open_tag, _, nested_self_close)) if open_tag == tag &&
        !nested_self_close => depth += 1
      _ => ()
    }
    body_lines.push(state.lines[i])
    i += 1
  }
  None
}

///|
fn parse_paragraph_block(state : BlockState, line : Int) -> Int? {
  if md_is_blank_line(state.lines[line]) {
    return None
  }
  let mut i = line
  let parts : Array[String] = []
  while i < state.lines.length() {
    let current = state.lines[i]
    if md_is_blank_line(current) {
      break
    }
    if i > line {
      let starts_special = md_is_special_block_start(current)
      let starts_table = md_is_table_start_with_next(state.lines, i)
      if starts_special || starts_table {
        break
      }
    }
    parts.push(md_trim_edges(current))
    i += 1
  }
  let body = parts.join(" ")
  state.tokens.push(
    make_token(
      "paragraph",
      "p",
      children=parse_inline_tokens_with_context(
        body,
        state.link_references,
        state.footnotes,
      ),
    ),
  )
  Some(i)
}

///|
fn block_rules() -> Array[BlockRule] {
  [
    parse_fence_block, parse_math_block, parse_heading_block, parse_table_block,
    parse_html_block, parse_blockquote_block, parse_unordered_list_block, parse_ordered_list_block,
    parse_paragraph_block,
  ]
}

///|
fn parse_blocks_from_lines(
  lines : Array[String],
  start_line : Int,
  link_references : Map[String, MdLinkReference],
  footnotes : Array[MdFootnote],
) -> Array[MdToken] {
  let state = BlockState::{ lines, tokens: [], link_references, footnotes }
  let rules = block_rules()
  let mut line = start_line
  while line < state.lines.length() {
    if md_is_blank_line(state.lines[line]) {
      line += 1
      continue
    }
    let mut matched = false
    for rule in rules {
      match rule(state, line) {
        Some(next) => {
          line = next
          matched = true
          break
        }
        None => ()
      }
    }
    if !matched {
      line += 1
    }
  }
  state.tokens
}
