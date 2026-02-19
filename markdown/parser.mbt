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
fn try_consume_front_matter(lines : Array[String]) -> (MdToken, Int)? {
  if lines.is_empty() || !md_is_front_matter_open(lines[0]) {
    return None
  }
  let body_lines : Array[String] = []
  let mut i = 1
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
  guard md_find_char_from(line, ':', 0) is Some(split_at) else {
    return None
  }
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
fn parse_metadata_from_front_matter_content(content : String) -> Array[MdMetadataItem] {
  let items : Array[MdMetadataItem] = []
  for line_view in content.split("\n") {
    let line = line_view.to_string()
    if md_trim_edges(line).is_empty() {
      continue
    }
    match md_split_first_colon(line) {
      Some((key, value)) => {
        items.push(
          MdMetadataItem::{
            key,
            value,
            value_tokens: parse_inline_tokens(value),
          },
        )
      }
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
    md_trim_edges(
      line.unsafe_substring(start=indent + 2, end=line.length()),
    ),
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
  if i + 1 >= len || md_char_at(line, i) != '.' || !md_is_space(md_char_at(line, i + 1)) {
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
  guard md_parse_table_cells(line) is Some(cells) else {
    return None
  }
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
  let is_blockquote = md_strip_blockquote_prefix(line) is Some(_)
  let is_bullet = md_parse_bullet_item(line) is Some(_)
  let is_ordered = md_parse_ordered_item(line) is Some(_)
  is_heading || is_fence || is_blockquote || is_bullet || is_ordered
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
    make_token(
      "fence",
      "code",
      content=code_lines.join("\n"),
      attrs~,
    ),
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
      children=parse_inline_tokens(body),
    ),
  )
  Some(line + 1)
}

///|
fn make_table_row_token(cells : Array[String], header : Bool) -> MdToken {
  let children = []
  for cell in cells {
    let typ = if header { "table_head_cell" } else { "table_cell" }
    let tag = if header { "th" } else { "td" }
    children.push(
      make_token(
        typ,
        tag,
        children=parse_inline_tokens(cell),
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
  let rows : Array[MdToken] = [make_table_row_token(header_cells, true)]
  let mut i = line + 2
  while i < state.lines.length() {
    if md_is_blank_line(state.lines[i]) {
      break
    }
    guard md_parse_table_cells(state.lines[i]) is Some(cells) else {
      break
    }
    if cells.length() != columns {
      break
    }
    rows.push(make_table_row_token(cells, false))
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
      children=parse_tokens_from_lines(inner_lines),
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
    guard md_parse_bullet_item(state.lines[i]) is Some(content) else {
      break
    }
    items.push(content)
    i += 1
  }
  let children = []
  for item in items {
    children.push(
      make_token(
        "list_item",
        "li",
        children=parse_inline_tokens(item),
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
        children=parse_inline_tokens(item),
      ),
    )
  }
  let attrs = [("start", start_text)]
  state.tokens.push(
    make_token(
      "ordered_list",
      "ol",
      attrs~,
      children=item_tokens,
    ),
  )
  Some(i)
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
      children=parse_inline_tokens(body),
    ),
  )
  Some(i)
}

///|
fn block_rules() -> Array[BlockRule] {
  [
    parse_fence_block,
    parse_heading_block,
    parse_table_block,
    parse_blockquote_block,
    parse_unordered_list_block,
    parse_ordered_list_block,
    parse_paragraph_block,
  ]
}

///|
fn parse_blocks_from_lines(lines : Array[String], start_line : Int) -> Array[MdToken] {
  let state = BlockState::{ lines, tokens: [] }
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

///|
fn parse_tokens_from_lines(lines : Array[String]) -> Array[MdToken] {
  let tokens : Array[MdToken] = []
  let mut start_line = 0
  match try_consume_front_matter(lines) {
    Some((front_matter, next_line)) => {
      tokens.push(front_matter)
      start_line = next_line
    }
    None => ()
  }
  for token in parse_blocks_from_lines(lines, start_line) {
    tokens.push(token)
  }
  tokens
}

///|
fn parse_document_from_lines(lines : Array[String]) -> MdDocument {
  let mut metadata : Array[MdMetadataItem] = []
  let mut start_line = 0
  match try_consume_front_matter(lines) {
    Some((front_matter, next_line)) => {
      metadata = parse_metadata_from_front_matter_content(front_matter.content)
      start_line = next_line
    }
    None => ()
  }
  MdDocument::{
    metadata,
    tokens: parse_blocks_from_lines(lines, start_line),
  }
}

///|
fn inline_rule_code(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if pos >= state.source.length() || md_char_at(state.source, pos) != '`' {
    return None
  }
  guard md_find_char_from(state.source, '`', pos + 1) is Some(end_index) else {
    return None
  }
  let content = state.source.unsafe_substring(start=pos + 1, end=end_index)
  Some((make_token("code_inline", "code", content~), end_index + 1))
}

///|
fn inline_rule_link(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if pos >= state.source.length() || md_char_at(state.source, pos) != '[' {
    return None
  }
  guard md_find_char_from(state.source, ']', pos + 1) is Some(close_bracket) else {
    return None
  }
  let open_paren = close_bracket + 1
  if open_paren >= state.source.length() || md_char_at(state.source, open_paren) != '(' {
    return None
  }
  guard
    md_find_char_from(state.source, ')', open_paren + 1) is Some(close_paren)
  else {
    return None
  }
  let label = state.source.unsafe_substring(start=pos + 1, end=close_bracket)
  let href = state.source.unsafe_substring(start=open_paren + 1, end=close_paren)
  let attrs = [("href", href)]
  Some(
    (
      make_token(
        "link",
        "a",
        attrs~,
        children=parse_inline_tokens(label),
      ),
      close_paren + 1,
    ),
  )
}

///|
fn inline_rule_strong(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if !md_has_prefix_at(state.source, pos, "**") {
    return None
  }
  guard md_find_substring_from(state.source, "**", pos + 2) is Some(end_index) else {
    return None
  }
  let inner = state.source.unsafe_substring(start=pos + 2, end=end_index)
  Some(
    (
      make_token(
        "strong",
        "strong",
        children=parse_inline_tokens(inner),
      ),
      end_index + 2,
    ),
  )
}

///|
fn inline_rule_em(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if pos >= state.source.length() || md_char_at(state.source, pos) != '*' {
    return None
  }
  if md_has_prefix_at(state.source, pos, "**") {
    return None
  }
  guard md_find_char_from(state.source, '*', pos + 1) is Some(end_index) else {
    return None
  }
  let inner = state.source.unsafe_substring(start=pos + 1, end=end_index)
  Some(
    (
      make_token(
        "em",
        "em",
        children=parse_inline_tokens(inner),
      ),
      end_index + 1,
    ),
  )
}

///|
fn inline_rule_text(state : InlineState, pos : Int) -> (MdToken, Int)? {
  let len = state.source.length()
  if pos >= len {
    return None
  }
  let mut i = pos
  while i < len {
    let ch = md_char_at(state.source, i)
    if ch == '`' || ch == '[' || ch == '*' {
      break
    }
    i += 1
  }
  if i == pos {
    i += 1
  }
  Some((
    make_token(
      "text",
      "",
      content=state.source.unsafe_substring(start=pos, end=i),
    ),
    i,
  ))
}

///|
fn inline_rules() -> Array[InlineRule] {
  [inline_rule_code, inline_rule_link, inline_rule_strong, inline_rule_em, inline_rule_text]
}

///|
fn parse_inline_tokens(source : String) -> Array[MdToken] {
  let state = InlineState::{ source, tokens: [] }
  let rules = inline_rules()
  let mut pos = 0
  while pos < state.source.length() {
    let mut matched = false
    for rule in rules {
      match rule(state, pos) {
        Some((token, next_pos)) => {
          state.tokens.push(token)
          pos = next_pos
          matched = true
          break
        }
        None => ()
      }
    }
    if !matched {
      pos += 1
    }
  }
  state.tokens
}

///|
fn split_markdown_lines(source : String) -> Array[String] {
  let lines = source.split("\n").map(StringView::to_string).collect()
  lines.map(md_strip_trailing_cr)
}

///|
pub fn MarkdownIt::parse_document(source : String) -> MdDocument {
  parse_document_from_lines(split_markdown_lines(source))
}

///|
pub fn MarkdownIt::parse(source : String) -> Array[MdToken] {
  parse_tokens_from_lines(split_markdown_lines(source))
}
