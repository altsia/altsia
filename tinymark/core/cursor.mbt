///|
priv struct Cursor {
  chars : Array[Char]
  index : Int
  source_id : String?
  line_offset : Int
  column_offset : Int
}

///|
fn Cursor::new_with_source(source : String, source_info : SourceInfo) -> Cursor {
  {
    chars: source.to_array(),
    index: 0,
    source_id: source_info.id,
    line_offset: source_info.line_offset,
    column_offset: source_info.column_offset,
  }
}

///|
fn Cursor::new_at_with_source(
  source : String,
  source_id : String?,
  line_offset : Int,
  column_offset : Int,
) -> Cursor {
  { chars: source.to_array(), index: 0, source_id, line_offset, column_offset }
}

///|
fn Cursor::is_end(self : Cursor) -> Bool {
  self.index >= self.chars.length()
}

///|
fn Cursor::length(self : Cursor) -> Int {
  self.chars.length()
}

///|
fn Cursor::char_at(self : Cursor, index : Int) -> Char {
  self.chars[index]
}

///|
fn Cursor::peek(self : Cursor) -> Char? {
  if self.is_end() {
    return None
  }
  Some(self.char_at(self.index))
}

///|
fn Cursor::advance(self : Cursor, amount : Int) -> Cursor {
  { ..self, index: self.index + amount }
}

///|
fn Cursor::at(self : Cursor, index : Int) -> Cursor {
  { ..self, index, }
}

///|
fn Cursor::error(self : Cursor, message : String) -> Diagnostic {
  self.source_span().diagnostic(DiagnosticPhase::Syntax, message)
}

///|
fn Cursor::slice_to_string(self : Cursor, start : Int, end : Int) -> String {
  String::from_array(self.chars.view(start~, end~))
}

///|
fn Cursor::line_column(self : Cursor) -> (Int, Int) {
  let (line, column) = self.local_line_column()
  if line != 1 {
    return (self.line_offset + line, column)
  }
  (self.line_offset + line, self.column_offset + column)
}

///|
fn Cursor::source_span(self : Cursor) -> SourceSpan {
  let (local_line, local_column) = self.local_line_column()
  let line = self.line_offset + local_line
  let column = if local_line == 1 {
    self.column_offset + local_column
  } else {
    local_column
  }
  let (line_start, line_end) = self.line_bounds()
  {
    source_id: self.source_id,
    line,
    column,
    marker_column: local_column,
    line_text: self.slice_to_string(line_start, line_end),
  }
}

///|
fn Cursor::local_line_column(self : Cursor) -> (Int, Int) {
  let mut line = 1
  let mut column = 1
  let mut index = 0
  let end = if self.index > self.length() { self.length() } else { self.index }
  while index < end {
    if is_newline(self.char_at(index)) {
      line += 1
      column = 1
    } else {
      column += 1
    }
    index += 1
  }
  (line, column)
}

///|
fn Cursor::line_bounds(self : Cursor) -> (Int, Int) {
  let mut current = if self.index > self.length() {
    self.length()
  } else {
    self.index
  }
  if current > 0 &&
    current == self.length() &&
    is_newline(self.char_at(current - 1)) {
    current -= 1
  }
  let mut start = current
  while start > 0 && !is_newline(self.char_at(start - 1)) {
    start -= 1
  }
  let mut end = current
  while end < self.length() && !is_newline(self.char_at(end)) {
    end += 1
  }
  (start, end)
}

///|
fn repeat_string(text : String, count : Int) -> String {
  let parts : Array[String] = []
  for _ in 0..<count {
    parts.push(text)
  }
  parts.join("")
}

///|
fn Cursor::starts_with(self : Cursor, text : String) -> Bool {
  let chars = text.to_array()
  if self.index + chars.length() > self.length() {
    return false
  }
  for i in 0..<chars.length() {
    if self.char_at(self.index + i) != chars[i] {
      return false
    }
  }
  true
}

///|
fn Cursor::at_line_start(self : Cursor) -> Bool {
  self.index == 0 || is_newline(self.char_at(self.index - 1))
}

///|
fn Cursor::skip_spaces(self : Cursor) -> Cursor {
  let mut index = self.index
  while index < self.length() {
    let ch = self.char_at(index)
    if is_layout_space(ch) {
      index += 1
    } else {
      break
    }
  }
  self.at(index)
}

///|
fn Cursor::skip_layout(self : Cursor) -> Cursor {
  let mut cursor = self
  let mut keep_going = true
  while keep_going {
    keep_going = false
    cursor = cursor.skip_spaces()
    if is_line_comment_start(cursor, cursor.index) {
      cursor = skip_line_comment(cursor)
      keep_going = true
    }
    if cursor.peek().map(is_newline).unwrap_or(false) {
      cursor = cursor.advance(1)
      keep_going = true
    }
  }
  cursor
}
