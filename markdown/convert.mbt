///|
fn push_shape_arg(
  args : Array[NormalizedShape],
  gaps : Array[Gap],
  node : NormalizedShape,
  gap_before? : Gap = Space,
) -> Unit {
  if args.is_empty() {
    args.push(node)
  } else {
    gaps.push(gap_before)
    args.push(node)
  }
}

///|
fn make_attr_shape(name : String, value : String) -> NormalizedShape {
  App([Text(":\{name}"), Text(value)], [Space])
}

///|
fn append_children_to_app(
  args : Array[NormalizedShape],
  gaps : Array[Gap],
  nodes : Array[NormalizedShape],
  node_gaps : Array[Gap],
) -> Unit {
  if nodes.is_empty() {
    return
  }
  push_shape_arg(args, gaps, nodes[0], gap_before=Space)
  for i in 1..<nodes.length() {
    push_shape_arg(args, gaps, nodes[i], gap_before=node_gaps[i - 1])
  }
}

///|
fn make_tag_shape_with_sequence(
  tag : String,
  attrs : Array[(String, String)],
  nodes : Array[NormalizedShape],
  node_gaps : Array[Gap],
) -> NormalizedShape {
  let args : Array[NormalizedShape] = [Text(tag)]
  let gaps : Array[Gap] = []
  for attr in attrs {
    push_shape_arg(
      args,
      gaps,
      make_attr_shape(attr.0, attr.1),
      gap_before=Space,
    )
  }
  append_children_to_app(args, gaps, nodes, node_gaps)
  App(args, gaps)
}

///|
fn make_tag_shape_with_children(
  tag : String,
  attrs : Array[(String, String)],
  children : Array[NormalizedShape],
) -> NormalizedShape {
  let child_gaps : Array[Gap] = []
  for _ in 1..<children.length() {
    child_gaps.push(Space)
  }
  make_tag_shape_with_sequence(tag, attrs, children, child_gaps)
}

///|
fn front_matter_to_shape(content : String) -> NormalizedShape {
  let args : Array[NormalizedShape] = [Text("%"), Text("front-matter")]
  let gaps : Array[Gap] = [Space]
  if !content.is_empty() {
    args.push(App([Text("code"), QuoteInline(content)], [Space]))
    gaps.push(Space)
  }
  App(args, gaps)
}

///|
fn metadata_item_to_shape(item : MdMetadataItem) -> NormalizedShape {
  let args : Array[NormalizedShape] = [Text(":\{item.key}")]
  let gaps : Array[Gap] = []
  let (nodes, node_gaps) = inline_tokens_to_shape_sequence(item.value_tokens)
  append_children_to_app(args, gaps, nodes, node_gaps)
  App(args, gaps)
}

///|
fn metadata_to_shape(items : Array[MdMetadataItem]) -> NormalizedShape? {
  if items.is_empty() {
    return None
  }
  let args : Array[NormalizedShape] = [Text("%"), Text("metadata")]
  let gaps : Array[Gap] = [Space]
  for item in items {
    push_shape_arg(args, gaps, metadata_item_to_shape(item), gap_before=Space)
  }
  Some(App(args, gaps))
}

///|
enum MathTextItem {
  Plain(String)
  Math(String, Bool)
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
fn find_end_of_math(
  delimiter : String,
  text : String,
  start_index : Int,
) -> Int? {
  let mut index = start_index
  let mut brace_level = 0
  while index < text.length() {
    let ch = md_char_at(text, index)
    if brace_level <= 0 && md_has_prefix_at(text, index, delimiter) {
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
fn math_is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn math_is_escaped_at(text : String, index : Int) -> Bool {
  if index <= 0 {
    return false
  }
  let mut backslashes = 0
  let mut i = index - 1
  while i >= 0 && md_char_at(text, i) == '\\' {
    backslashes += 1
    if i == 0 {
      break
    }
    i -= 1
  }
  backslashes % 2 == 1
}

///|
fn math_valid_open(text : String, index : Int, delimiter_length : Int) -> Bool {
  if math_is_escaped_at(text, index) {
    return false
  }
  let right_index = index + delimiter_length
  if right_index >= text.length() {
    return false
  }
  !md_is_space(md_char_at(text, right_index))
}

///|
fn math_valid_close(text : String, index : Int, delimiter_length : Int) -> Bool {
  if math_is_escaped_at(text, index) {
    return false
  }
  if index <= 0 || md_is_space(md_char_at(text, index - 1)) {
    return false
  }
  let right_index = index + delimiter_length
  if right_index < text.length() && math_is_digit(md_char_at(text, right_index)) {
    return false
  }
  true
}

///|
fn find_next_unescaped_dollar(text : String, start : Int) -> Int? {
  let mut i = start
  while i < text.length() {
    if md_char_at(text, i) == '$' && !math_is_escaped_at(text, i) {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn split_text_math_items(text : String) -> Array[MathTextItem] {
  let items : Array[MathTextItem] = []
  let mut i = 0
  let len = text.length()
  while i < len {
    guard find_next_unescaped_dollar(text, i) is Some(open_index) else {
      items.push(Plain(text.unsafe_substring(start=i, end=len)))
      break
    }
    if open_index > i {
      items.push(Plain(text.unsafe_substring(start=i, end=open_index)))
    }
    let mut delimiter = ""
    let mut delimiter_length = 0
    let mut is_display = false
    let can_open_display = md_has_prefix_at(text, open_index, "$$") && math_valid_open(text, open_index, 2)
    if can_open_display {
      delimiter = "$$"
      delimiter_length = 2
      is_display = true
    } else if math_valid_open(text, open_index, 1) {
      delimiter = "$"
      delimiter_length = 1
    } else {
      items.push(Plain("$"))
      i = open_index + 1
      continue
    }
    let close = match
      find_end_of_math(delimiter, text, open_index + delimiter_length) {
      Some(found) if math_valid_close(text, found, delimiter_length) => found
      _ => -1
    }
    if close < 0 {
      items.push(Plain(delimiter))
      i = open_index + delimiter_length
      continue
    }
    let tex = text.unsafe_substring(
      start=open_index + delimiter_length,
      end=close,
    )
    items.push(Math(tex, is_display))
    i = close + delimiter_length
  }
  items
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
fn inline_container_token_to_shape(token : MdToken) -> NormalizedShape {
  let (children, child_gaps) = inline_tokens_to_shape_sequence(token.children)
  make_tag_shape_with_sequence(token.tag, token.attrs, children, child_gaps)
}

///|
fn inline_tokens_to_shape_sequence(
  tokens : Array[MdToken],
) -> (Array[NormalizedShape], Array[Gap]) {
  let nodes : Array[NormalizedShape] = []
  let gaps : Array[Gap] = []
  let mut pending_space = false
  for token in tokens {
    match token.typ {
      "text" => {
        for item in split_text_math_items(token.content) {
          match item {
            Plain(content) => {
              let leading = text_has_leading_space(content)
              let trailing = text_has_trailing_space(content)
              let body = md_trim_edges(content)
              if body.is_empty() {
                if text_has_space(content) {
                  pending_space = true
                }
                continue
              }
              let gap_before = if nodes.is_empty() {
                Tight
              } else if pending_space || leading {
                Space
              } else {
                Tight
              }
              push_shape_arg(nodes, gaps, Text(body), gap_before=gap_before)
              pending_space = trailing
            }
            Math(tex, display) => {
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
                make_math_shape(tex, display),
                gap_before=gap_before,
              )
              pending_space = false
            }
          }
        }
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
        push_shape_arg(nodes, gaps, node, gap_before=gap_before)
        pending_space = false
      }
      _ => {
        let node = inline_container_token_to_shape(token)
        let gap_before = if nodes.is_empty() {
          Tight
        } else if pending_space {
          Space
        } else {
          Tight
        }
        push_shape_arg(nodes, gaps, node, gap_before=gap_before)
        pending_space = false
      }
    }
  }
  (nodes, gaps)
}

///|
fn fence_info(token : MdToken) -> String? {
  for attr in token.attrs {
    if attr.0 == "info" {
      return Some(attr.1)
    }
  }
  None
}

///|
fn fence_token_to_shape(token : MdToken) -> NormalizedShape {
  let code_attrs = []
  match fence_info(token) {
    Some(info) if !info.is_empty() =>
      code_attrs.push(("class", "language-\{info}"))
    _ => ()
  }
  let code_node =
    if token.content.is_empty() {
      make_tag_shape_with_children("code", code_attrs, [])
    } else {
      make_tag_shape_with_children("code", code_attrs, [Text(token.content)])
    }
  make_tag_shape_with_children("pre", [], [code_node])
}

///|
fn block_token_to_shape(token : MdToken) -> NormalizedShape {
  match token.typ {
    "front_matter" => front_matter_to_shape(token.content)
    "paragraph" | "heading" | "list_item" | "table_head_cell" | "table_cell" => {
      let (nodes, node_gaps) = inline_tokens_to_shape_sequence(token.children)
      make_tag_shape_with_sequence(token.tag, token.attrs, nodes, node_gaps)
    }
    "bullet_list" | "ordered_list" | "blockquote" | "table" | "table_head_row" | "table_row" =>
      make_tag_shape_with_children(
        token.tag,
        token.attrs,
        token.children.map(block_token_to_shape),
      )
    "fence" => fence_token_to_shape(token)
    _ =>
      make_tag_shape_with_children(
        "p",
        [],
        [Text(token.content)],
      )
  }
}

///|
fn escape_shape_text(value : String) -> String {
  value.replace_all(old="(", new="\\(").replace_all(old=")", new="\\)")
}

///|
fn render_shape_inline_quote(content : String) -> String {
  "`\{content}`"
}

///|
pub fn normalized_shape_to_source(node : NormalizedShape) -> String {
  match node {
    Text(value) => escape_shape_text(value)
    QuoteInline(content) => render_shape_inline_quote(content)
    App(args, gaps) => {
      let mut inline = ""
      for i in 0..<args.length() {
        let gap_before = if i == 0 { Tight } else { gaps[i - 1] }
        if i > 0 && gap_before == Space {
          inline = inline + " "
        }
        inline = inline + normalized_shape_to_source(args[i])
      }
      "(\{inline})"
    }
  }
}

///|
pub fn normalized_shapes_to_source(nodes : Array[NormalizedShape]) -> String {
  nodes.map(normalized_shape_to_source).join("\n\n")
}

///|
pub fn MarkdownIt::to_shapes(source : String) -> Array[NormalizedShape] {
  let document = MarkdownIt::parse_document(source)
  let shapes : Array[NormalizedShape] = []
  match metadata_to_shape(document.metadata) {
    Some(node) => shapes.push(node)
    None => ()
  }
  for token in document.tokens {
    shapes.push(block_token_to_shape(token))
  }
  shapes
}

///|
pub fn MarkdownIt::to_altsia(
  source : String,
  normalize? : Bool = true,
  max_width? : Int = @core.default_max_width,
) -> String raise {
  let rendered = MarkdownIt::to_shapes(source) |> normalized_shapes_to_source
  if normalize {
    @core.Stage1::normalize(rendered, max_width~)
  } else {
    rendered
  }
}
