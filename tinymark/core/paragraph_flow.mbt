///|
pub(all) enum ParagraphPart {
  Text(String)
  Break
} derive(Eq, Debug)

///|
pub fn split_paragraph_text(text : String) -> Array[ParagraphPart] {
  let parts : Array[ParagraphPart] = []
  let chars = text.to_array()
  let mut start = 0
  let mut index = 0
  while index < chars.length() {
    match paragraph_break_end(chars, index) {
      Some(break_end) => {
        if index > start {
          parts.push(Text(String::from_array(chars.view(start~, end=index))))
        }
        parts.push(Break)
        index = break_end
        start = index
      }
      None => index += 1
    }
  }
  if start < chars.length() {
    parts.push(Text(String::from_array(chars.view(start~))))
  }
  parts
}

///|
pub fn has_paragraph_break(text : String) -> Bool {
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() {
    if paragraph_break_end(chars, index) is Some(_) {
      return true
    }
    index += 1
  }
  false
}

///|
fn paragraph_break_end(chars : Array[Char], index : Int) -> Int? {
  if chars[index] != '\n' {
    return None
  }
  let mut scan = index + 1
  while scan < chars.length() && is_blank_line_space(chars[scan]) {
    scan += 1
  }
  if scan < chars.length() && chars[scan] == '\n' {
    return Some(scan + 1)
  }
  None
}

///|
fn is_blank_line_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r'
}

///|
pub fn clamp_heading_level(level : Int) -> Int {
  level.clamp(min=1, max=6)
}
