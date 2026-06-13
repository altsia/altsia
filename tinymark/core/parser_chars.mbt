///|
fn is_newline(ch : Char) -> Bool {
  ch == '\n'
}

///|
fn is_layout_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r'
}

///|
fn is_name_boundary(ch : Char) -> Bool {
  ch.is_whitespace() || ch == '(' || ch == ')' || ch == '"' || ch == '`'
}

///|
fn is_text_boundary(ch : Char) -> Bool {
  ch == '(' || ch == ')' || ch == '`' || ch == '"' || ch == '*'
}

///|
fn is_escapable_text_char(ch : Char) -> Bool {
  ch == '(' || ch == ')' || ch == '`' || ch == '*' || ch == '-' || ch == '+'
}

///|
fn is_raw_string_delimiter(ch : Char) -> Bool {
  ch == '`'
}

///|
fn is_list_sugar_marker(ch : Char) -> Bool {
  ch == '-' || ch == '+'
}

///|
fn is_line_comment_start(cursor : Cursor, index : Int) -> Bool {
  cursor.char_at(index) == ';' &&
  index + 1 < cursor.length() &&
  cursor.char_at(index + 1) == ';'
}

///|
fn is_line_start_at(cursor : Cursor, index : Int) -> Bool {
  index == 0 || is_newline(cursor.char_at(index - 1))
}

///|
fn is_block_quote_fence_start(cursor : Cursor) -> Bool {
  cursor.starts_with("```")
}

///|
fn is_block_quote_fence(text : String) -> Bool {
  text.has_prefix("```")
}

///|
fn is_line_end(ch : Char) -> Bool {
  is_newline(ch)
}

///|
fn is_line_or_list_end(ch : Char) -> Bool {
  is_newline(ch) || ch == ')'
}

///|
fn is_trim_space(ch : Char) -> Bool {
  ch.is_whitespace()
}
