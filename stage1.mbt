///|
pub(all) enum S {
  Text(String)
  Block(String)
  App(@list.List[S])
} derive(Eq, Debug, Show)

///|
pub type Stage1

///|
fn is_stage1_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn skip_stage1_spaces(source : String, start : Int) -> Int {
  let skipped = source.iter().drop(start).take_while(is_stage1_space).count()
  start + skipped
}

///|
fn has_prefix_at(source : String, start : Int, prefix : String) -> Bool {
  let end_index = start + prefix.length()
  if end_index > source.length() {
    return false
  }
  source.unsafe_substring(start~, end=end_index) == prefix
}

///|
fn is_stage1_indent_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
fn is_stage1_blank_line(line : String) -> Bool {
  line.iter().all(fn(ch) { is_stage1_indent_char(ch) || ch == '\r' })
}

///|
fn stage1_leading_indent(line : String) -> Int {
  line.iter().take_while(is_stage1_indent_char).count()
}

///|
fn strip_trailing_cr(line : String) -> String {
  if line.is_empty() {
    return line
  }
  if char_at(line, line.length() - 1) == '\r' {
    return line.unsafe_substring(start=0, end=line.length() - 1)
  }
  line
}

///|
fn merge_min_indent(acc : Int?, indent : Int) -> Int? {
  match acc {
    None => Some(indent)
    Some(prev) => Some(if indent < prev { indent } else { prev })
  }
}

///|
fn strip_line_common_indent(line : String, min_indent : Int) -> String {
  let cut = if min_indent > line.length() { line.length() } else { min_indent }
  line.unsafe_substring(start=cut, end=line.length())
}

///|
fn fold_lines_with_newline(acc : String, line : String) -> String {
  if acc.is_empty() {
    line
  } else {
    acc + "\n" + line
  }
}

///|
fn normalize_quote_content(raw : String) -> String {
  let lines = raw
    .split("\n")
    .map(StringView::to_string)
    .map(strip_trailing_cr)
    .collect()
  let min_indent = lines
    .iter()
    .filter(fn(line) { !is_stage1_blank_line(line) })
    .map(stage1_leading_indent)
    .fold(init=None, merge_min_indent)
  let min_indent = match min_indent {
    None => 0
    Some(indent) => indent
  }
  lines
  .iter()
  .map(fn(line) { strip_line_common_indent(line, min_indent) })
  .fold(init="", fold_lines_with_newline)
}

///|
fn parse_quote_block(source : String, start : Int) -> (String, Int) {
  if !has_prefix_at(source, start, "```") {
    panic()
  }
  let len = source.length()
  let mut i = start + 3
  if i < len && char_at(source, i) == '\r' {
    i += 1
  }
  if i < len && char_at(source, i) == '\n' {
    i += 1
  }
  let content_start = i
  let mut line_start = i
  while i + 2 < len {
    if has_prefix_at(source, i, "```") {
      let mut j = line_start
      let mut only_indent_before_fence = true
      while j < i {
        if !is_stage1_indent_char(char_at(source, j)) {
          only_indent_before_fence = false
          break
        }
        j += 1
      }
      if only_indent_before_fence {
        let raw_content = source.unsafe_substring(
          start=content_start,
          end=line_start,
        )
        return (normalize_quote_content(raw_content), i + 3)
      }
    }
    let ch = char_at(source, i)
    i += 1
    if ch == '\n' {
      line_start = i
    }
  }
  panic()
}

///|
fn push_plain_argument(
  args : Array[S],
  source : String,
  start : Int,
  end_index : Int,
) -> Unit {
  if start < 0 || start >= end_index {
    return
  }
  let raw = source.unsafe_substring(start~, end=end_index)
  let content = raw
    .trim()
    .to_string()
    .replace_all(old="\\(", new="(")
    .replace_all(old="\\)", new=")")
  if !content.is_empty() {
    args.push(Text(content))
  }
}

///|
fn parse_app(source : String, start : Int) -> (S, Int) {
  // Phase 1: parse the outer opening `(` and read the first argument (head).
  let len = source.length()
  if start >= len || char_at(source, start) != '(' {
    panic()
  }
  let mut i = start + 1
  let args : Array[S] = []
  i = skip_stage1_spaces(source, i)
  if i >= len {
    panic()
  }
  if char_at(source, i) == ')' {
    return (App(@list.List::from_array(args)), i + 1)
  }
  if char_at(source, i) == '(' {
    let (head, next) = parse_app(source, i)
    args.push(head)
    i = next
  } else {
    let head_start = i
    while i < len {
      let ch = char_at(source, i)
      if is_stage1_space(ch) || ch == ')' {
        break
      }
      i += 1
    }
    if head_start == i {
      panic()
    }
    let head = source
      .unsafe_substring(start=head_start, end=i)
      .replace_all(old="\\(", new="(")
      .replace_all(old="\\)", new=")")
    args.push(Text(head))
  }

  // Phase 2: scan remaining content inside this app.
  // `segment_start` tracks a pending plain-text segment:
  // - on unescaped `(`: flush plain text, then parse nested app recursively
  // - on unescaped `)`: flush plain text, then finish current app
  let mut segment_start = -1
  while i < len {
    let ch = char_at(source, i)
    if ch == ')' && !(i > 0 && char_at(source, i - 1) == '\\') {
      push_plain_argument(args, source, segment_start, i)
      return (App(@list.List::from_array(args)), i + 1)
    }
    if ch == '(' && !(i > 0 && char_at(source, i - 1) == '\\') {
      push_plain_argument(args, source, segment_start, i)
      segment_start = -1
      let (nested, next) = parse_app(source, i)
      args.push(nested)
      i = next
      continue
    }
    if segment_start == -1 {
      segment_start = i
    }
    i += 1
  }
  panic()
}

///|
fn append_quote_to_last_app(result : Array[S], quote_content : String) -> Unit {
  if result.is_empty() {
    panic()
  }
  let last_index = result.length() - 1
  match result[last_index] {
    App(args) => {
      let updated = args.to_array()
      updated.push(Block(quote_content))
      result[last_index] = App(@list.List::from_array(updated))
    }
    Block(_) | Text(_) => panic()
  }
}

///|
pub fn Stage1::parse(source : String) -> Array[S] {
  let len = source.length()
  let mut i = 0
  let result : Array[S] = []
  while i < len {
    i = skip_stage1_spaces(source, i)
    if i >= len {
      break
    }
    if has_prefix_at(source, i, "```") {
      let (quote_content, next) = parse_quote_block(source, i)
      append_quote_to_last_app(result, quote_content)
      i = next
      continue
    }
    if char_at(source, i) == '(' {
      let (node, next) = parse_app(source, i)
      result.push(node)
      i = next
      continue
    }
    panic()
  }
  result
}

///|
fn escape_text(value : String) -> String {
  value.replace_all(old="(", new="\\(").replace_all(old=")", new="\\)")
}

///|
fn render_block(content : String) -> String {
  let body = if content.has_suffix("\n") { content } else { content + "\n" }
  "```\n" + body + "```"
}

///|
fn render_app(args : @list.List[S]) -> String {
  let inline_parts : Array[String] = []
  let blocks : Array[String] = []
  for arg in args {
    match arg {
      Block(content) => blocks.push(render_block(content))
      Text(text) => inline_parts.push(escape_text(text))
      App(nested) => inline_parts.push(render_app(nested))
    }
  }
  let app_line = "(" + inline_parts.join(" ") + ")"
  if blocks.is_empty() {
    app_line
  } else {
    app_line + "\n" + blocks.join("\n")
  }
}

///|
impl ToSource for S with to_source(node) {
  match node {
    Text(value) => escape_text(value)
    Block(content) => render_block(content)
    App(args) => render_app(args)
  }
}

///|
pub fn to_source(nodes : Array[S]) -> String {
  nodes.map(ToSource::to_source).join("\n\n")
}
