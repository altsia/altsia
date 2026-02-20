///|
enum InlineHtmlTag {
  Open(String, Array[(String, String)], Bool)
  Close(String)
  Other
} derive(Eq, Show, Debug)

///|
fn make_math_shape(tex : String, display : Bool) -> NormalizedShape {
  if display {
    App([Text("kd"), QuoteInline(tex)], [Space])
  } else {
    App([Text("k"), QuoteInline(tex)], [Space])
  }
}

///|
fn text_has_space(content : String) -> Bool {
  content.iter().any(md_is_space)
}

///|
fn text_has_leading_space(content : String) -> Bool {
  if content.is_empty() {
    return false
  }
  md_is_space(md_char_at(content, 0))
}

///|
fn text_has_trailing_space(content : String) -> Bool {
  if content.is_empty() {
    return false
  }
  md_is_space(md_char_at(content, content.length() - 1))
}

///|
fn inline_container_token_to_shape(
  token : MdToken,
  ctx : ConvertContext,
) -> NormalizedShape {
  let (children, child_gaps) = inline_tokens_to_shape_sequence(
    token.children,
    ctx,
  )
  make_tag_shape_with_sequence(token.tag, token.attrs, children, child_gaps)
}

///|
fn html_skip_spaces(source : String, start : Int, end_exclusive : Int) -> Int {
  let mut i = start
  while i < end_exclusive && md_is_space(md_char_at(source, i)) {
    i += 1
  }
  i
}

///|
fn html_read_name(
  source : String,
  start : Int,
  end_exclusive : Int,
) -> (String, Int)? {
  if start >= end_exclusive || !md_is_ascii_letter(md_char_at(source, start)) {
    return None
  }
  let mut i = start + 1
  while i < end_exclusive && md_is_html_name_char(md_char_at(source, i)) {
    i += 1
  }
  Some((source.unsafe_substring(start~, end=i), i))
}

///|
fn parse_inline_html_tag(content : String) -> InlineHtmlTag {
  let len = content.length()
  if len < 3 ||
    md_char_at(content, 0) != '<' ||
    md_char_at(content, len - 1) != '>' {
    return Other
  }
  if md_has_prefix_at(content, 0, "<!--") {
    return Other
  }
  let last = len - 1
  let mut i = 1
  let first = md_char_at(content, i)
  if first == '!' || first == '?' {
    return Other
  }
  if first == '/' {
    i = html_skip_spaces(content, i + 1, last)
    guard html_read_name(content, i, last) is Some((name, next_i)) else {
      return Other
    }
    i = html_skip_spaces(content, next_i, last)
    return if i == last { Close(name) } else { Other }
  }
  guard html_read_name(content, i, last) is Some((name, next_i)) else {
    return Other
  }
  i = next_i
  let attrs : Array[(String, String)] = []
  let mut self_close = false
  while i < last {
    i = html_skip_spaces(content, i, last)
    if i >= last {
      break
    }
    if md_char_at(content, i) == '/' {
      if i + 1 == last {
        self_close = true
        i += 1
        break
      }
      return Other
    }
    guard html_read_name(content, i, last) is Some((attr_name, attr_end)) else {
      return Other
    }
    i = html_skip_spaces(content, attr_end, last)
    let mut attr_value = "true"
    if i < last && md_char_at(content, i) == '=' {
      i += 1
      i = html_skip_spaces(content, i, last)
      if i >= last {
        attr_value = ""
      } else {
        let ch = md_char_at(content, i)
        if ch == '"' || ch == '\'' {
          let quote = ch
          let value_start = i + 1
          i += 1
          while i < last && md_char_at(content, i) != quote {
            i += 1
          }
          if i >= last {
            return Other
          }
          attr_value = content.unsafe_substring(start=value_start, end=i)
          i += 1
        } else {
          let value_start = i
          while i < last {
            let current = md_char_at(content, i)
            if md_is_space(current) || (current == '/' && i + 1 == last) {
              break
            }
            i += 1
          }
          attr_value = content.unsafe_substring(start=value_start, end=i)
        }
      }
    }
    attrs.push((attr_name, attr_value))
  }
  Open(name, attrs, self_close)
}

///|
fn copy_token_range(
  tokens : Array[MdToken],
  start_inclusive : Int,
  end_exclusive : Int,
) -> Array[MdToken] {
  let result : Array[MdToken] = []
  let mut i = start_inclusive
  while i < end_exclusive {
    result.push(tokens[i])
    i += 1
  }
  result
}

///|
fn try_inline_html_element(
  tokens : Array[MdToken],
  start_index : Int,
  ctx : ConvertContext,
) -> (NormalizedShape, Int)? {
  if start_index >= tokens.length() || tokens[start_index].typ != "html_inline" {
    return None
  }
  match parse_inline_html_tag(tokens[start_index].content) {
    Open(name, attrs, self_close) => {
      if self_close {
        return Some(
          (make_tag_shape_with_children(name, attrs, []), start_index + 1),
        )
      }
      let mut depth = 0
      let mut i = start_index + 1
      while i < tokens.length() {
        if tokens[i].typ == "html_inline" {
          match parse_inline_html_tag(tokens[i].content) {
            Open(inner, _, nested_self_close) if inner == name &&
              !nested_self_close => depth += 1
            Close(inner) if inner == name => {
              if depth == 0 {
                let child_tokens = copy_token_range(tokens, start_index + 1, i)
                let (children, child_gaps) = inline_tokens_to_shape_sequence(
                  child_tokens, ctx,
                )
                return Some(
                  (
                    make_tag_shape_with_sequence(
                      name, attrs, children, child_gaps,
                    ),
                    i + 1,
                  ),
                )
              }
              depth -= 1
            }
            _ => ()
          }
        }
        i += 1
      }
      None
    }
    _ => None
  }
}

///|
fn inline_tokens_to_shape_sequence(
  tokens : Array[MdToken],
  ctx : ConvertContext,
) -> (Array[NormalizedShape], Array[Gap]) {
  let nodes : Array[NormalizedShape] = []
  let gaps : Array[Gap] = []
  let mut pending_space = false
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    match token.typ {
      "text" => {
        let leading = text_has_leading_space(token.content)
        let trailing = text_has_trailing_space(token.content)
        let body = md_trim_edges(token.content)
        if body.is_empty() {
          if text_has_space(token.content) {
            pending_space = true
          }
          i += 1
          continue
        }
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space || leading {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, Text(body), gap_before~)
        pending_space = trailing
        i += 1
      }
      "math_inline" | "math_display_inline" => {
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(
          nodes,
          gaps,
          make_math_shape(token.content, token.typ == "math_display_inline"),
          gap_before~,
        )
        pending_space = false
        i += 1
      }
      "code_inline" => {
        let node = App([Text("code"), QuoteInline(token.content)], [Space])
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, node, gap_before~)
        pending_space = false
        i += 1
      }
      "link_ref" => {
        let (children, child_gaps) = inline_tokens_to_shape_sequence(
          token.children,
          ctx,
        )
        let href_node = match token_attr_value(token, "ref") {
          Some(label) =>
            match ctx.link_lambda_map.get(label) {
              Some(lambda_name) => make_empty_call_shape(lambda_name)
              None =>
                match token_attr_value(token, "href") {
                  Some(href) => Text(href)
                  None => Text("")
                }
            }
          None =>
            match token_attr_value(token, "href") {
              Some(href) => Text(href)
              None => Text("")
            }
        }
        let link_args : Array[NormalizedShape] = [Text(token.tag)]
        let link_gaps : Array[Gap] = []
        for attr in token.attrs {
          if attr.0 == "ref" || attr.0 == "href" {
            continue
          }
          push_shape_arg(
            link_args,
            link_gaps,
            make_attr_shape(attr.0, attr.1),
            gap_before=Space,
          )
        }
        push_shape_arg(
          link_args,
          link_gaps,
          make_attr_shape_with_node("href", href_node),
          gap_before=Space,
        )
        append_children_to_app(link_args, link_gaps, children, child_gaps)
        let node = App(link_args, link_gaps)
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, node, gap_before~)
        pending_space = false
        i += 1
      }
      "footnote_ref" => {
        let node = match token_attr_value(token, "ref") {
          Some(label) =>
            match ctx.footnote_ref_lambda_map.get(label) {
              Some(lambda_name) => make_empty_call_shape(lambda_name)
              None => Text("[^\{label}]")
            }
          None => Text("[^]")
        }
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, node, gap_before~)
        pending_space = false
        i += 1
      }
      "html_inline" =>
        match try_inline_html_element(tokens, i, ctx) {
          Some((node, next_i)) => {
            let gap_before = if nodes.is_empty() {
              Tight
            } else if pending_space {
              Space
            } else {
              Tight
            }
            push_shape_arg(nodes, gaps, node, gap_before~)
            pending_space = false
            i = next_i
          }
          None => {
            let gap_before = if nodes.is_empty() {
              Tight
            } else if pending_space {
              Space
            } else {
              Tight
            }
            push_shape_arg(nodes, gaps, Text(token.content), gap_before~)
            pending_space = false
            i += 1
          }
        }
      _ => {
        let node = inline_container_token_to_shape(token, ctx)
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, node, gap_before~)
        pending_space = false
        i += 1
      }
    }
  }
  (nodes, gaps)
}

///|
