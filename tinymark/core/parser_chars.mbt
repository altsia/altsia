///|
fn Parser::is_newline(ch : Char) -> Bool {
  ch == '\n'
}

///|
fn Parser::is_layout_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r'
}

///|
fn Parser::is_name_boundary(ch : Char) -> Bool {
  ch.is_whitespace() || ch == '(' || ch == ')' || ch == '"' || ch == '`'
}

///|
fn Parser::is_text_boundary(ch : Char) -> Bool {
  ch == '(' || ch == ')' || ch == '`' || ch == '"' || ch == '*'
}

///|
fn Parser::is_escapable_text_char(ch : Char) -> Bool {
  ch == '(' || ch == ')' || ch == '`' || ch == '*' || ch == '-' || ch == '+'
}

///|
fn Parser::is_list_sugar_marker(ch : Char) -> Bool {
  ch == '-' || ch == '+'
}

///|
fn Parser::is_line_comment_start(cursor : Cursor, index : Int) -> Bool {
  cursor.chars[index] == ';' &&
  index + 1 < cursor.chars.length() &&
  cursor.chars[index + 1] == ';'
}

///|
fn Parser::is_line_start_at(cursor : Cursor, index : Int) -> Bool {
  index == 0 || Parser::is_newline(cursor.chars[index - 1])
}

///|
fn Parser::is_block_quote_fence_start(cursor : Cursor) -> Bool {
  cursor.starts_with("```")
}

///|
fn Parser::is_block_quote_fence(text : String) -> Bool {
  text.has_prefix("```")
}

///|
fn is_line_or_list_end(ch : Char) -> Bool {
  Parser::is_newline(ch) || ch == ')'
}
