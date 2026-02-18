///|
pub(all) enum S {
  Text(String, SourceLoc)
  /// Multi-line text syntax sugar
  QuoteInline(String, SourceLoc)
  /// Multi-line text syntax sugar (strip common spaces at the beginning of lines)
  QuoteBlock(String, SourceLoc)
  App(Array[S], SourceLoc)
} derive(Eq, Debug, Show)

///|
pub fn S::loc(node : S) -> SourceLoc {
  match node {
    Text(_, loc) => loc
    QuoteBlock(_, loc) => loc
    QuoteInline(_, loc) => loc
    App(_, loc) => loc
  }
}

///|
pub(all) suberror Stage1Error {
  InvalidQuoteBlockStart(loc~ : SourceLoc)
  InvalidApplicationStart(loc~ : SourceLoc)
  UnexpectedEof(context~ : String, loc~ : SourceLoc)
  EmptyApplicationHead(loc~ : SourceLoc)
  UnclosedApplication(loc~ : SourceLoc)
  UnclosedQuoteBlock(loc~ : SourceLoc)
  UnclosedQuoteInline(loc~ : SourceLoc)
  QuoteBlockRequiresPrecedingApp(loc~ : SourceLoc)
  QuoteBlockMustFollowApp(loc~ : SourceLoc)
  UnexpectedTopLevelToken(token~ : String, loc~ : SourceLoc)
} derive(Eq, Show)

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
fn one_char_loc(source : String, i : Int) -> SourceLoc {
  let start = if i < 0 {
    0
  } else if i > source.length() {
    source.length()
  } else {
    i
  }
  let end = if start < source.length() { start + 1 } else { start }
  source_loc_from_offsets(source, start, end)
}

///|
fn end_loc(source : String) -> SourceLoc {
  source_loc_from_offsets(source, source.length(), source.length())
}

///|
fn parse_quote_block(source : String, start : Int) -> (String, Int) raise {
  if !has_prefix_at(source, start, "```") {
    raise Stage1Error::InvalidQuoteBlockStart(loc=one_char_loc(source, start))
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
  raise Stage1Error::UnclosedQuoteBlock(
    loc=source_loc_from_offsets(source, start, len),
  )
}

///|
fn parse_quote_inline(source : String, start : Int) -> (String, Int) raise {
  let len = source.length()
  let mut i = start + 1
  while i < len {
    if char_at(source, i) == '`' {
      return (source.unsafe_substring(start=start + 1, end=i), i + 1)
    }
    i += 1
  }
  raise Stage1Error::UnclosedQuoteInline(
    loc=source_loc_from_offsets(source, start, len),
  )
}

///|
fn trim_segment_bounds(
  source : String,
  start : Int,
  end_index : Int,
) -> (Int, Int) {
  let mut left = start
  let mut right = end_index
  while left < right && is_stage1_space(char_at(source, left)) {
    left += 1
  }
  while right > left && is_stage1_space(char_at(source, right - 1)) {
    right -= 1
  }
  (left, right)
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
  let (trim_start, trim_end) = trim_segment_bounds(source, start, end_index)
  if trim_start >= trim_end {
    return
  }
  let raw = source.unsafe_substring(start=trim_start, end=trim_end)
  let content = raw
    .replace_all(old="\\(", new="(")
    .replace_all(old="\\)", new=")")
  if !content.is_empty() {
    args.push(
      Text(content, source_loc_from_offsets(source, trim_start, trim_end)),
    )
  }
}

///|
fn parse_app(source : String, start : Int) -> (S, Int) raise {
  // Phase 1: parse the outer opening `(` and read the first argument (head).
  let len = source.length()
  if start >= len {
    raise Stage1Error::UnexpectedEof(
      context="application start",
      loc=end_loc(source),
    )
  }
  if char_at(source, start) != '(' {
    raise Stage1Error::InvalidApplicationStart(loc=one_char_loc(source, start))
  }
  let mut i = start + 1
  let args : Array[S] = []
  i = skip_stage1_spaces(source, i)
  if i >= len {
    raise Stage1Error::UnexpectedEof(
      context="application head",
      loc=end_loc(source),
    )
  }
  if char_at(source, i) == ')' {
    return (App(args, source_loc_from_offsets(source, start, i + 1)), i + 1)
  }
  if char_at(source, i) == '`' {
    let quote_start = i
    let (quote_content, next) = parse_quote_inline(source, i)
    args.push(
      QuoteInline(
        quote_content,
        source_loc_from_offsets(source, quote_start, next),
      ),
    )
    i = next
  } else if char_at(source, i) == '(' {
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
      raise Stage1Error::EmptyApplicationHead(loc=one_char_loc(source, i))
    }
    let head = source
      .unsafe_substring(start=head_start, end=i)
      .replace_all(old="\\(", new="(")
      .replace_all(old="\\)", new=")")
    args.push(Text(head, source_loc_from_offsets(source, head_start, i)))
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
      return (App(args, source_loc_from_offsets(source, start, i + 1)), i + 1)
    }
    if ch == '(' && !(i > 0 && char_at(source, i - 1) == '\\') {
      push_plain_argument(args, source, segment_start, i)
      segment_start = -1
      let (nested, next) = parse_app(source, i)
      args.push(nested)
      i = next
      continue
    }
    if ch == '`' && !(i > 0 && char_at(source, i - 1) == '\\') {
      push_plain_argument(args, source, segment_start, i)
      segment_start = -1
      let quote_start = i
      let (quote_content, next) = parse_quote_inline(source, i)
      args.push(
        QuoteInline(
          quote_content,
          source_loc_from_offsets(source, quote_start, next),
        ),
      )
      i = next
      continue
    }
    if segment_start == -1 {
      segment_start = i
    }
    i += 1
  }
  raise Stage1Error::UnclosedApplication(
    loc=source_loc_from_offsets(source, start, len),
  )
}

///|
fn append_quote_to_last_app(
  result : Array[S],
  quote_content : String,
  quote_loc : SourceLoc,
) -> Unit raise {
  if result.is_empty() {
    raise Stage1Error::QuoteBlockRequiresPrecedingApp(loc=quote_loc)
  }
  let last_index = result.length() - 1
  match result[last_index] {
    App(args, app_loc) => {
      let updated = []
      updated.append(args)
      updated.push(QuoteBlock(quote_content, quote_loc))
      result[last_index] = App(updated, app_loc)
    }
    QuoteBlock(_, _) | QuoteInline(_, _) | Text(_, _) =>
      raise Stage1Error::QuoteBlockMustFollowApp(loc=quote_loc)
  }
}

///|
pub fn Stage1::parse(source : String) -> Array[S] raise {
  let len = source.length()
  let mut i = 0
  let result : Array[S] = []
  while i < len {
    i = skip_stage1_spaces(source, i)
    if i >= len {
      break
    }
    if has_prefix_at(source, i, "```") {
      let quote_start = i
      let (quote_content, next) = parse_quote_block(source, i)
      append_quote_to_last_app(
        result,
        quote_content,
        source_loc_from_offsets(source, quote_start, next),
      )
      i = next
      continue
    }
    if char_at(source, i) == '(' {
      let (node, next) = parse_app(source, i)
      result.push(node)
      i = next
      continue
    }
    let token = source.unsafe_substring(start=i, end=i + 1)
    raise Stage1Error::UnexpectedTopLevelToken(
      token~,
      loc=one_char_loc(source, i),
    )
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
fn render_inline_quote(content : String) -> String {
  "`" + content + "`"
}

///|
fn render_app(args : Array[S]) -> String {
  let inline_parts : Array[String] = []
  let blocks : Array[String] = []
  for arg in args {
    match arg {
      QuoteBlock(content, _) => blocks.push(render_block(content))
      QuoteInline(content, _) => inline_parts.push(render_inline_quote(content))
      Text(text, _) => inline_parts.push(escape_text(text))
      App(nested, _) => inline_parts.push(render_app(nested))
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
    Text(value, _) => escape_text(value)
    QuoteBlock(content, _) => render_block(content)
    QuoteInline(content, _) => render_inline_quote(content)
    App(args, _) => render_app(args)
  }
}

///|
pub fn to_source(nodes : Array[S]) -> String {
  nodes.map(ToSource::to_source).join("\n\n")
}
