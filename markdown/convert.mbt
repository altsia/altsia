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
priv struct ConvertContext {
  link_lambda_map : Array[(String, String)]
  footnote_ref_lambda_map : Array[(String, String)]
  footnote_item_lambda_names : Array[String]
}

///|
fn empty_convert_context() -> ConvertContext {
  ConvertContext::{
    link_lambda_map: [],
    footnote_ref_lambda_map: [],
    footnote_item_lambda_names: [],
  }
}

///|
fn lookup_mapped_name(map : Array[(String, String)], key : String) -> String? {
  for entry in map {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn token_attr_value(token : MdToken, key : String) -> String? {
  for attr in token.attrs {
    if attr.0 == key {
      return Some(attr.1)
    }
  }
  None
}

///|
fn make_call_shape_from_sequence(
  fn_name : String,
  nodes : Array[NormalizedShape],
  node_gaps : Array[Gap],
) -> NormalizedShape {
  let args : Array[NormalizedShape] = [Text(fn_name)]
  let gaps : Array[Gap] = []
  append_children_to_app(args, gaps, nodes, node_gaps)
  App(args, gaps)
}

///|
fn make_lambda_shape(
  name : String,
  params : Array[String],
  body : Array[NormalizedShape],
) -> NormalizedShape {
  let param_nodes = params.map(fn(param) { Text(param) })
  let param_gaps : Array[Gap] = []
  for _ in 1..<param_nodes.length() {
    param_gaps.push(Space)
  }
  let args : Array[NormalizedShape] = [
    Text("λ"),
    Text(name),
    App(param_nodes, param_gaps),
  ]
  let gaps : Array[Gap] = [Space, Space]
  for term in body {
    push_shape_arg(args, gaps, term, gap_before=Space)
  }
  App(args, gaps)
}

///|
fn make_empty_call_shape(name : String) -> NormalizedShape {
  App([Text(name)], [])
}

///|
fn make_param_ref_shape(name : String) -> NormalizedShape {
  make_empty_call_shape(name)
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
  let (nodes, node_gaps) = inline_tokens_to_shape_sequence(
    item.value_tokens,
    empty_convert_context(),
  )
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
  let (children, child_gaps) = inline_tokens_to_shape_sequence(token.children, ctx)
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
                  child_tokens,
                  ctx,
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
        let node = match token_attr_value(token, "ref") {
          Some(label) =>
            match lookup_mapped_name(ctx.link_lambda_map, label) {
              Some(lambda_name) =>
                make_call_shape_from_sequence(lambda_name, children, child_gaps)
              None =>
                make_tag_shape_with_sequence(
                  token.tag,
                  token.attrs.filter(fn(attr) { attr.0 != "ref" }),
                  children,
                  child_gaps,
                )
            }
          None =>
            make_tag_shape_with_sequence(
              token.tag,
              token.attrs.filter(fn(attr) { attr.0 != "ref" }),
              children,
              child_gaps,
            )
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
      "footnote_ref" => {
        let node = match token_attr_value(token, "ref") {
          Some(label) =>
            match lookup_mapped_name(ctx.footnote_ref_lambda_map, label) {
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
  let code_node = if token.content.is_empty() {
    make_tag_shape_with_children("code", code_attrs, [])
  } else {
    make_tag_shape_with_children("code", code_attrs, [Text(token.content)])
  }
  make_tag_shape_with_children("pre", [], [code_node])
}

///|
fn block_token_to_shape(token : MdToken, ctx : ConvertContext) -> NormalizedShape {
  match token.typ {
    "front_matter" => front_matter_to_shape(token.content)
    "math_block" => App([Text("kd"), QuoteInline(token.content)], [Space])
    "paragraph" | "heading" | "list_item" | "table_head_cell" | "table_cell" => {
      let (nodes, node_gaps) = inline_tokens_to_shape_sequence(
        token.children,
        ctx,
      )
      make_tag_shape_with_sequence(token.tag, token.attrs, nodes, node_gaps)
    }
    "bullet_list"
    | "ordered_list"
    | "blockquote"
    | "table"
    | "table_head_row"
    | "table_row"
    | "html_block" =>
      make_tag_shape_with_children(
        token.tag,
        token.attrs,
        token.children.map(fn(child) { block_token_to_shape(child, ctx) }),
      )
    "fence" => fence_token_to_shape(token)
    _ => make_tag_shape_with_children("p", [], [Text(token.content)])
  }
}

///|
fn make_link_lambda_name(index : Int) -> String {
  "md_link_ref_\{index}"
}

///|
fn make_footnote_ref_lambda_name(index : Int) -> String {
  "md_footnote_ref_\{index}"
}

///|
fn make_footnote_item_lambda_name(index : Int) -> String {
  "md_footnote_item_\{index}"
}

///|
fn make_footnote_anchor_id(index : Int) -> String {
  "md-footnote-\{index}"
}

///|
fn build_convert_context(document : MdDocument) -> ConvertContext {
  let link_lambda_map : Array[(String, String)] = []
  for i in 0..<document.link_references.length() {
    let item = document.link_references[i]
    link_lambda_map.push((item.label, make_link_lambda_name(i + 1)))
  }
  let footnote_ref_lambda_map : Array[(String, String)] = []
  let footnote_item_lambda_names : Array[String] = []
  for i in 0..<document.footnotes.length() {
    let item = document.footnotes[i]
    footnote_ref_lambda_map.push((item.label, make_footnote_ref_lambda_name(i + 1)))
    footnote_item_lambda_names.push(make_footnote_item_lambda_name(i + 1))
  }
  ConvertContext::{
    link_lambda_map,
    footnote_ref_lambda_map,
    footnote_item_lambda_names,
  }
}

///|
fn make_link_lambda_shape(name : String, href : String) -> NormalizedShape {
  let body = make_tag_shape_with_children(
    "a",
    [("href", href)],
    [make_param_ref_shape("content")],
  )
  make_lambda_shape(name, ["content..."], [body])
}

///|
fn make_footnote_ref_lambda_shape(
  name : String,
  anchor_id : String,
  display_index : Int,
) -> NormalizedShape {
  let link_node = make_tag_shape_with_children(
    "a",
    [("href", "#\{anchor_id}")],
    [Text(display_index.to_string())],
  )
  let body = make_tag_shape_with_children("sup", [], [link_node])
  make_lambda_shape(name, [], [body])
}

///|
fn make_footnote_item_lambda_shape(
  name : String,
  anchor_id : String,
  footnote : MdFootnote,
  ctx : ConvertContext,
) -> NormalizedShape {
  let (nodes, node_gaps) = inline_tokens_to_shape_sequence(footnote.value_tokens, ctx)
  let body = make_tag_shape_with_sequence(
    "li",
    [("id", anchor_id)],
    nodes,
    node_gaps,
  )
  make_lambda_shape(name, [], [body])
}

///|
fn make_lambda_declarations(
  document : MdDocument,
  ctx : ConvertContext,
) -> Array[NormalizedShape] {
  let declarations : Array[NormalizedShape] = []
  for i in 0..<document.link_references.length() {
    let item = document.link_references[i]
    declarations.push(
      make_link_lambda_shape(make_link_lambda_name(i + 1), item.href),
    )
  }
  for i in 0..<document.footnotes.length() {
    let footnote = document.footnotes[i]
    let index = i + 1
    let anchor_id = make_footnote_anchor_id(index)
    declarations.push(
      make_footnote_ref_lambda_shape(
        make_footnote_ref_lambda_name(index),
        anchor_id,
        index,
      ),
    )
    declarations.push(
      make_footnote_item_lambda_shape(
        make_footnote_item_lambda_name(index),
        anchor_id,
        footnote,
        ctx,
      ),
    )
  }
  declarations
}

///|
fn make_footnotes_section_shape(ctx : ConvertContext) -> NormalizedShape? {
  if ctx.footnote_item_lambda_names.is_empty() {
    return None
  }
  let items = ctx.footnote_item_lambda_names.map(fn(lambda_name) {
    make_empty_call_shape(lambda_name)
  })
  let list_node = make_tag_shape_with_children("ol", [], items)
  Some(make_tag_shape_with_children("section", [("class", "footnotes")], [list_node]))
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
    App([Text("k"), QuoteInline(content)], _) => "k`\{content}`"
    App([Text("kd"), QuoteInline(content)], _) => "kd`\{content}`"
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
  let ctx = build_convert_context(document)
  let shapes : Array[NormalizedShape] = []
  match metadata_to_shape(document.metadata) {
    Some(node) => shapes.push(node)
    None => ()
  }
  for node in make_lambda_declarations(document, ctx) {
    shapes.push(node)
  }
  for token in document.tokens {
    shapes.push(block_token_to_shape(token, ctx))
  }
  match make_footnotes_section_shape(ctx) {
    Some(node) => shapes.push(node)
    None => ()
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
