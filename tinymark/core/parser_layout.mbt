///|
fn skip_line_comment(cursor : Cursor) -> Cursor {
  let mut index = cursor.index
  while index < cursor.length() && !is_newline(cursor.char_at(index)) {
    index += 1
  }
  cursor.at(index)
}

///|
fn skip_attach_space(cursor : Cursor) -> (Cursor, Bool) {
  let mut index = cursor.index
  let mut newline_count = 0
  while index < cursor.length() {
    let ch = cursor.char_at(index)
    if is_layout_space(ch) {
      index += 1
      continue
    }
    if is_newline(ch) {
      newline_count += 1
      if newline_count >= 2 {
        return (cursor.at(index), true)
      }
      index += 1
      continue
    }
    break
  }
  (cursor.at(index), false)
}

///|
fn skip_content_layout(
  cursor : Cursor,
  close : Char?,
  can_skip_spaces : Bool,
) -> Cursor {
  let mut current = cursor
  let mut skip_spaces = can_skip_spaces
  let mut keep_going = true
  while keep_going {
    keep_going = false
    let spaced = current.skip_spaces()
    match close {
      Some(ch) if spaced.peek() == Some(ch) => return spaced
      _ => ()
    }
    if spaced.is_end() {
      return spaced
    }
    if is_line_comment_start(spaced, spaced.index) {
      current = skip_line_comment(spaced)
      skip_spaces = true
      keep_going = true
    } else if spaced.peek().map(is_newline).unwrap_or(false) {
      current = spaced.advance(1)
      skip_spaces = true
      keep_going = true
    } else if skip_spaces {
      current = spaced
    }
  }
  current
}
