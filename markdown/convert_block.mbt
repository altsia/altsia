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
fn block_token_to_shape(
  token : MdToken,
  ctx : ConvertContext,
) -> NormalizedShape {
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
