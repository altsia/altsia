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
fn md_lookup_link_reference(
  refs : Map[String, MdLinkReference],
  raw_label : String,
) -> MdLinkReference? {
  let key = md_normalize_reference_label(raw_label)
  if key.is_empty() {
    return None
  }
  refs.get(key)
}

///|
fn md_has_footnote(footnotes : Array[MdFootnote], raw_label : String) -> Bool {
  let key = md_normalize_reference_label(raw_label)
  if key.is_empty() {
    return false
  }
  footnotes.iter().any(fn(item) { item.label == key })
}

///|
fn inline_rule_footnote_ref(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if pos + 2 >= state.source.length() ||
    !md_has_prefix_at(state.source, pos, "[^") {
    return None
  }
  guard md_find_char_from(state.source, ']', pos + 2) is Some(close_bracket) else {
    return None
  }
  let raw_label = state.source.unsafe_substring(
    start=pos + 2,
    end=close_bracket,
  )
  if !md_has_footnote(state.footnotes, raw_label) {
    return None
  }
  let label = md_normalize_reference_label(raw_label)
  let attrs = [("ref", label)]
  Some((make_token("footnote_ref", "fnref", attrs~), close_bracket + 1))
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
  if open_paren < state.source.length() &&
    md_char_at(state.source, open_paren) == '(' {
    guard md_find_char_from(state.source, ')', open_paren + 1)
      is Some(close_paren) else {
      return None
    }
    let label = state.source.unsafe_substring(start=pos + 1, end=close_bracket)
    let href = state.source.unsafe_substring(
      start=open_paren + 1,
      end=close_paren,
    )
    let attrs = [("href", href)]
    return Some(
      (
        make_token(
          "link",
          "a",
          attrs~,
          children=parse_inline_tokens_with_context(
            label,
            state.link_references,
            state.footnotes,
          ),
        ),
        close_paren + 1,
      ),
    )
  }
  let label = state.source.unsafe_substring(start=pos + 1, end=close_bracket)
  if open_paren < state.source.length() &&
    md_char_at(state.source, open_paren) == '[' {
    guard md_find_char_from(state.source, ']', open_paren + 1)
      is Some(close_ref) else {
      return None
    }
    let raw_ref = state.source.unsafe_substring(
      start=open_paren + 1,
      end=close_ref,
    )
    let lookup_label = if raw_ref.is_empty() { label } else { raw_ref }
    guard md_lookup_link_reference(state.link_references, lookup_label)
      is Some(link_ref) else {
      return None
    }
    let attrs = [("ref", link_ref.label), ("href", link_ref.href)]
    return Some(
      (
        make_token(
          "link_ref",
          "a",
          attrs~,
          children=parse_inline_tokens_with_context(
            label,
            state.link_references,
            state.footnotes,
          ),
        ),
        close_ref + 1,
      ),
    )
  }
  guard md_lookup_link_reference(state.link_references, label) is Some(link_ref) else {
    return None
  }
  let attrs = [("ref", link_ref.label), ("href", link_ref.href)]
  Some(
    (
      make_token(
        "link_ref",
        "a",
        attrs~,
        children=parse_inline_tokens_with_context(
          label,
          state.link_references,
          state.footnotes,
        ),
      ),
      close_bracket + 1,
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
        children=parse_inline_tokens_with_context(
          inner,
          state.link_references,
          state.footnotes,
        ),
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
        children=parse_inline_tokens_with_context(
          inner,
          state.link_references,
          state.footnotes,
        ),
      ),
      end_index + 1,
    ),
  )
}

///|
fn md_math_is_escaped_at(source : String, index : Int) -> Bool {
  if index <= 0 {
    return false
  }
  let mut backslashes = 0
  let mut i = index - 1
  while i >= 0 && md_char_at(source, i) == '\\' {
    backslashes += 1
    if i == 0 {
      break
    }
    i -= 1
  }
  backslashes % 2 == 1
}

///|
fn md_math_valid_open(
  source : String,
  index : Int,
  delimiter_length : Int,
) -> Bool {
  if md_math_is_escaped_at(source, index) {
    return false
  }
  let right_index = index + delimiter_length
  right_index < source.length()
}

///|
fn md_math_valid_close(
  source : String,
  index : Int,
) -> Bool {
  if md_math_is_escaped_at(source, index) {
    return false
  }
  index > 0
}

///|
fn md_find_end_of_math(
  delimiter : String,
  source : String,
  start_index : Int,
) -> Int? {
  let mut index = start_index
  let mut brace_level = 0
  while index < source.length() {
    let ch = md_char_at(source, index)
    if brace_level <= 0 && md_has_prefix_at(source, index, delimiter) {
      return Some(index)
    } else if ch == '\\' {
      index += 1
    } else if ch == '{' {
      brace_level += 1
    } else if ch == '}' {
      brace_level -= 1
    }
    index += 1
  }
  None
}

///|
fn inline_rule_math(state : InlineState, pos : Int) -> (MdToken, Int)? {
  let source = state.source
  if pos >= source.length() || md_char_at(source, pos) != '$' {
    return None
  }

  let mut delimiter = "$"
  let mut delimiter_length = 1
  let mut is_display = false
  let can_open_display = md_has_prefix_at(source, pos, "$$") &&
    md_math_valid_open(source, pos, 2)
  if can_open_display {
    delimiter = "$$"
    delimiter_length = 2
    is_display = true
  } else if !md_math_valid_open(source, pos, 1) {
    return Some((make_token("text", "", content="$"), pos + 1))
  }

  let close = match
    md_find_end_of_math(delimiter, source, pos + delimiter_length) {
    Some(found) if md_math_valid_close(source, found) => found
    _ => -1
  }
  if close < 0 {
    return Some(
      (make_token("text", "", content=delimiter), pos + delimiter_length),
    )
  }

  let tex = source.unsafe_substring(start=pos + delimiter_length, end=close)
  let typ = if is_display { "math_display_inline" } else { "math_inline" }
  Some((make_token(typ, "", content=tex), close + delimiter_length))
}

///|
fn scan_inline_html_tag_end(source : String, pos : Int) -> Int? {
  let len = source.length()
  if pos + 1 >= len || md_char_at(source, pos) != '<' {
    return None
  }
  let first = md_char_at(source, pos + 1)
  if first == '!' {
    if md_has_prefix_at(source, pos, "<!--") {
      guard md_find_substring_from(source, "-->", pos + 4) is Some(close) else {
        return None
      }
      return Some(close + 3)
    }
    guard md_find_char_from(source, '>', pos + 2) is Some(close) else {
      return None
    }
    return Some(close + 1)
  }
  if first == '?' {
    guard md_find_char_from(source, '>', pos + 2) is Some(close) else {
      return None
    }
    return Some(close + 1)
  }
  if first == '/' {
    let mut i = pos + 2
    if i >= len || !md_is_ascii_letter(md_char_at(source, i)) {
      return None
    }
    while i < len && md_is_html_name_char(md_char_at(source, i)) {
      i += 1
    }
    while i < len && md_is_space(md_char_at(source, i)) {
      i += 1
    }
    if i < len && md_char_at(source, i) == '>' {
      return Some(i + 1)
    }
    return None
  }
  if !md_is_ascii_letter(first) {
    return None
  }
  let mut i = pos + 2
  while i < len && md_is_html_name_char(md_char_at(source, i)) {
    i += 1
  }
  let mut quote : Char? = None
  while i < len {
    let ch = md_char_at(source, i)
    match quote {
      Some(current) => if ch == current { quote = None }
      None =>
        if ch == '"' || ch == '\'' {
          quote = Some(ch)
        } else if ch == '>' {
          return Some(i + 1)
        }
    }
    i += 1
  }
  None
}

///|
fn inline_rule_html(state : InlineState, pos : Int) -> (MdToken, Int)? {
  if pos >= state.source.length() || md_char_at(state.source, pos) != '<' {
    return None
  }
  guard scan_inline_html_tag_end(state.source, pos) is Some(end) else {
    return None
  }
  Some(
    (
      make_token(
        "html_inline",
        "",
        content=state.source.unsafe_substring(start=pos, end~),
      ),
      end,
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
    if ch == '`' || ch == '[' || ch == '*' || ch == '<' || ch == '$' {
      break
    }
    i += 1
  }
  if i == pos {
    i += 1
  }
  Some(
    (
      make_token(
        "text",
        "",
        content=state.source.unsafe_substring(start=pos, end=i),
      ),
      i,
    ),
  )
}

///|
fn inline_rules() -> Array[InlineRule] {
  [
    inline_rule_code, inline_rule_footnote_ref, inline_rule_link, inline_rule_strong,
    inline_rule_em, inline_rule_html, inline_rule_math, inline_rule_text,
  ]
}

///|
fn parse_inline_tokens_with_context(
  source : String,
  link_references : Map[String, MdLinkReference],
  footnotes : Array[MdFootnote],
) -> Array[MdToken] {
  let state = InlineState::{ source, tokens: [], link_references, footnotes }
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
fn parse_inline_tokens(source : String) -> Array[MdToken] {
  parse_inline_tokens_with_context(source, Map::new(), [])
}
