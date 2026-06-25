///|
fn append_paragraph_content_node(
  inline_run : Array[HtmlNode],
  out : Array[HtmlNode],
  node : HtmlNode,
) -> Unit {
  match node {
    HtmlNode::Text(text) if has_paragraph_break(text) =>
      append_text_with_paragraph_splits(inline_run, out, text)
    _ => inline_run.push(node)
  }
}

///|
fn flush_paragraph(inline_run : Array[HtmlNode], out : Array[HtmlNode]) -> Unit {
  if !inline_run.is_empty() {
    if inline_run_only_blank_text(inline_run) {
      out.append(inline_run.copy())
    } else {
      out.push(HtmlNode::Element("p", @sexp.HtmlAttrs({}), inline_run.copy()))
    }
    inline_run.clear()
  }
}

///|
fn inline_run_only_blank_text(inline_run : Array[HtmlNode]) -> Bool {
  for node in inline_run {
    match node {
      HtmlNode::Text(text) if text.is_blank() => ()
      _ => return false
    }
  }
  true
}

///|
fn append_text_with_paragraph_splits(
  inline_run : Array[HtmlNode],
  out : Array[HtmlNode],
  text : String,
) -> Unit {
  let chars = text.to_array()
  let mut start = 0
  let mut index = 0
  while index < chars.length() {
    match paragraph_break_end(chars, index) {
      Some(break_end) => {
        if index > start {
          inline_run.push(
            HtmlNode::Text(String::from_array(chars.view(start~, end=index))),
          )
        }
        flush_paragraph(inline_run, out)
        index = break_end
        start = index
      }
      None => index += 1
    }
  }
  if start < chars.length() {
    inline_run.push(HtmlNode::Text(String::from_array(chars.view(start~))))
  }
}

///|
fn has_paragraph_break(text : String) -> Bool {
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
fn clamp_heading_level(level : Int) -> Int {
  level.clamp(min=1, max=6)
}
