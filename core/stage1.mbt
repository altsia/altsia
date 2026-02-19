///|
pub(all) enum S {
  Text(String, SourceLoc)
  /// Multi-line text syntax sugar
  QuoteInline(String, SourceLoc)
  /// Multi-line text syntax sugar (strip common spaces at the beginning of lines)
  QuoteBlock(String, SourceLoc)
  App(Array[S], Array[AppGap], SourceLoc)
} derive(Eq, Debug, Show)

///|
pub(all) enum AppGap {
  Tight
  Space
} derive(Eq, Debug, Show)

///|
pub fn S::loc(node : S) -> SourceLoc {
  match node {
    Text(_, loc) => loc
    QuoteBlock(_, loc) => loc
    QuoteInline(_, loc) => loc
    App(_, _, loc) => loc
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
fn parse_quote_block_app_from_head(
  source : String,
  head_start : Int,
  quote_start : Int,
) -> (S, Int) raise {
  let head_raw = source.unsafe_substring(start=head_start, end=quote_start)
  let head = head_raw
    .replace_all(old="\\(", new="(")
    .replace_all(old="\\)", new=")")
  let (quote_content, next) = parse_quote_block(source, quote_start)
  let head_node : S = Text(
    head,
    source_loc_from_offsets(source, head_start, quote_start),
  )
  let quote_node : S = QuoteBlock(
    quote_content,
    source_loc_from_offsets(source, quote_start, next),
  )
  let app_node : S = App(
    [head_node, quote_node],
    [Space],
    source_loc_from_offsets(source, head_start, next),
  )
  (
    app_node,
    next,
  )
}

///|
fn trim_segment_bounds(
  source : String,
  start : Int,
  end_index : Int,
  trim_left? : Bool = true,
  trim_right? : Bool = true,
) -> (Int, Int) {
  let mut left = start
  let mut right = end_index
  if trim_left {
    while left < right && is_stage1_space(char_at(source, left)) {
      left += 1
    }
  }
  if trim_right {
    while right > left && is_stage1_space(char_at(source, right - 1)) {
      right -= 1
    }
  }
  (left, right)
}

///|
fn parse_plain_argument(
  source : String,
  start : Int,
  end_index : Int,
  trim_left? : Bool = true,
  trim_right? : Bool = true,
) -> S? {
  if start < 0 || start >= end_index {
    return None
  }
  let (trim_start, trim_end) = trim_segment_bounds(
    source,
    start,
    end_index,
    trim_left~,
    trim_right~,
  )
  if trim_start >= trim_end {
    return None
  }
  let raw = source.unsafe_substring(start=trim_start, end=trim_end)
  let content = raw
    .replace_all(old="\\(", new="(")
    .replace_all(old="\\)", new=")")
  if content.iter().all(is_stage1_space) {
    return None
  }
  if content.is_empty() {
    None
  } else {
    Some(Text(content, source_loc_from_offsets(source, trim_start, trim_end)))
  }
}

///|
fn infer_app_gap(source : String, left_end : Int, right_start : Int) -> AppGap {
  if right_start <= left_end {
    return Tight
  }
  let mut i = left_end
  let mut has_space = false
  while i < right_start {
    if is_stage1_space(char_at(source, i)) {
      has_space = true
      break
    }
    i += 1
  }
  if has_space {
    Space
  } else {
    Tight
  }
}

///|
fn push_app_arg(
  args : Array[S],
  gaps : Array[AppGap],
  source : String,
  node : S,
) -> Unit {
  if !args.is_empty() {
    let prev_end = args[args.length() - 1].loc().end_offset
    let next_start = node.loc().start_offset
    gaps.push(infer_app_gap(source, prev_end, next_start))
  }
  args.push(node)
}

///|
fn parse_quote_inline_app_from_head(
  source : String,
  head_start : Int,
  quote_start : Int,
) -> (S, Int) raise {
  let head_raw = source.unsafe_substring(start=head_start, end=quote_start)
  let head = head_raw
    .replace_all(old="\\(", new="(")
    .replace_all(old="\\)", new=")")
  let (quote_content, next) = parse_quote_inline(source, quote_start)
  let head_node : S = Text(
    head,
    source_loc_from_offsets(source, head_start, quote_start),
  )
  let quote_node : S = QuoteInline(
    quote_content,
    source_loc_from_offsets(source, quote_start, next),
  )
  let app_node : S = App(
    [head_node, quote_node],
    [Space],
    source_loc_from_offsets(source, head_start, next),
  )
  (
    app_node,
    next,
  )
}

///|
fn try_parse_quote_inline_app_token(
  source : String,
  start : Int,
) -> (S, Int)? raise {
  let len = source.length()
  if start >= len {
    return None
  }
  let first = char_at(source, start)
  if first == '`' || first == '(' || first == ')' {
    return None
  }
  let mut i = start
  while i < len {
    let ch = char_at(source, i)
    if ch == '`' && !(i > 0 && char_at(source, i - 1) == '\\') {
      if has_prefix_at(source, i, "```") {
        return None
      }
      break
    }
    if is_stage1_space(ch) || ch == '(' || ch == ')' {
      return None
    }
    i += 1
  }
  if i <= start || i >= len {
    return None
  }
  Some(parse_quote_inline_app_from_head(source, start, i))
}

///|
fn try_parse_quote_block_app_token(
  source : String,
  start : Int,
) -> (S, Int)? raise {
  let len = source.length()
  if start >= len {
    return None
  }
  let first = char_at(source, start)
  if first == '`' || first == '(' || first == ')' {
    return None
  }
  let mut i = start
  while i < len {
    let ch = char_at(source, i)
    if has_prefix_at(source, i, "```") &&
      !(i > 0 && char_at(source, i - 1) == '\\') {
      break
    }
    if is_stage1_space(ch) || ch == '(' || ch == ')' {
      return None
    }
    i += 1
  }
  if i <= start || i >= len || !has_prefix_at(source, i, "```") {
    return None
  }
  Some(parse_quote_block_app_from_head(source, start, i))
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
  let gaps : Array[AppGap] = []
  i = skip_stage1_spaces(source, i)
  if i >= len {
    raise Stage1Error::UnexpectedEof(
      context="application head",
      loc=end_loc(source),
    )
  }
  if char_at(source, i) == ')' {
    return (
      App(args, gaps, source_loc_from_offsets(source, start, i + 1)),
      i + 1,
    )
  }
  if char_at(source, i) == '`' {
    let quote_start = i
    let (quote_content, next) = parse_quote_inline(source, i)
    push_app_arg(
      args,
      gaps,
      source,
      QuoteInline(
        quote_content,
        source_loc_from_offsets(source, quote_start, next),
      ),
    )
    i = next
  } else if char_at(source, i) == '(' {
    let (head, next) = parse_app(source, i)
    push_app_arg(args, gaps, source, head)
    i = next
  } else {
    let head_start = i
    while i < len {
      let ch = char_at(source, i)
      if is_stage1_space(ch) ||
        ch == ')' ||
        (ch == '`' && !(i > 0 && char_at(source, i - 1) == '\\')) {
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
    push_app_arg(
      args,
      gaps,
      source,
      Text(head, source_loc_from_offsets(source, head_start, i)),
    )
  }

  // Phase 2: scan remaining content inside this app.
  // `segment_start` tracks a pending plain-text segment:
  // - on unescaped `(`: flush plain text, then parse nested app recursively
  // - on unescaped `)`: flush plain text, then finish current app
  let mut segment_start = -1
  while i < len {
    let ch = char_at(source, i)
    if ch == ')' && !(i > 0 && char_at(source, i - 1) == '\\') {
      match parse_plain_argument(source, segment_start, i) {
        Some(plain) => push_app_arg(args, gaps, source, plain)
        None => ()
      }
      return (
        App(args, gaps, source_loc_from_offsets(source, start, i + 1)),
        i + 1,
      )
    }
    if ch == '(' && !(i > 0 && char_at(source, i - 1) == '\\') {
      match parse_plain_argument(source, segment_start, i) {
        Some(plain) => push_app_arg(args, gaps, source, plain)
        None => ()
      }
      segment_start = -1
      let (nested, next) = parse_app(source, i)
      push_app_arg(args, gaps, source, nested)
      i = next
      continue
    }
    if ch == '`' && !(i > 0 && char_at(source, i - 1) == '\\') {
      if segment_start != -1 {
        let mut head_start = i
        while head_start > segment_start &&
          !is_stage1_space(char_at(source, head_start - 1)) {
          head_start -= 1
        }
        if head_start < i {
          match parse_plain_argument(source, segment_start, head_start) {
            Some(plain) => push_app_arg(args, gaps, source, plain)
            None => ()
          }
          let (quote_app, next) = parse_quote_inline_app_from_head(
            source,
            head_start,
            i,
          )
          push_app_arg(args, gaps, source, quote_app)
          segment_start = -1
          i = next
          continue
        }
      }
      match parse_plain_argument(source, segment_start, i) {
        Some(plain) => push_app_arg(args, gaps, source, plain)
        None => ()
      }
      segment_start = -1
      let quote_start = i
      let (quote_content, next) = parse_quote_inline(source, i)
      push_app_arg(
        args,
        gaps,
        source,
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
  source : String,
) -> Unit raise {
  if result.is_empty() {
    raise Stage1Error::QuoteBlockRequiresPrecedingApp(loc=quote_loc)
  }
  let last_index = result.length() - 1
  match result[last_index] {
    App(args, gaps, app_loc) => {
      let updated_args = []
      updated_args.append(args)
      let updated_gaps = []
      updated_gaps.append(gaps)
      let quote = QuoteBlock(quote_content, quote_loc)
      push_app_arg(updated_args, updated_gaps, source, quote)
      result[last_index] = App(updated_args, updated_gaps, app_loc)
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
        source,
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
    match try_parse_quote_block_app_token(source, i) {
      Some((node, next)) => {
        result.push(node)
        i = next
        continue
      }
      None => ()
    }
    match try_parse_quote_inline_app_token(source, i) {
      Some((node, next)) => {
        result.push(node)
        i = next
        continue
      }
      None => ()
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
fn render_app(args : Array[S], gaps : Array[AppGap]) -> String {
  let inline_parts : Array[(String, AppGap)] = []
  let blocks : Array[String] = []
  for i in 0..<args.length() {
    let arg = args[i]
    let gap = if i == 0 { Tight } else { gaps[i - 1] }
    match arg {
      QuoteBlock(content, _) => blocks.push(render_block(content))
      QuoteInline(content, _) =>
        inline_parts.push((render_inline_quote(content), gap))
      Text(text, _) => inline_parts.push((escape_text(text), gap))
      App(nested, nested_gaps, _) =>
        inline_parts.push((render_app(nested, nested_gaps), gap))
    }
  }
  let mut inline_line = ""
  for i in 0..<inline_parts.length() {
    let (part, gap) = inline_parts[i]
    if i > 0 && gap == Space {
      inline_line = inline_line + " "
    }
    inline_line = inline_line + part
  }
  let app_line = "(" + inline_line + ")"
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
    App(args, gaps, _) => render_app(args, gaps)
  }
}

///|
pub fn to_source(nodes : Array[S]) -> String {
  nodes.map(ToSource::to_source).join("\n\n")
}
