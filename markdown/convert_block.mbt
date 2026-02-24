// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

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
fn math_block_token_to_shape(
  token : MdToken,
  convert_katex : KatexConvertMode,
) -> NormalizedShape {
  if should_convert_katex_to_app(token.content, convert_katex) {
    return App([Text("kd"), QuoteInline(token.content)], [Space])
  }
  if token_attr_value(token, "math_style") == Some("multi_line") {
    Text("$$\n\{token.content}\n$$")
  } else {
    Text("$$\{token.content}$$")
  }
}

///|
fn paragraph_single_macro_math_shape(
  token : MdToken,
  ctx : ConvertContext,
) -> NormalizedShape? {
  if token.typ != "paragraph" || token.children.length() != 1 {
    return None
  }
  let child = token.children[0]
  if (child.typ != "math_inline" && child.typ != "math_display_inline") ||
    !is_katex_macro_definition(child.content) {
    return None
  }
  Some(
    make_math_shape(
      child.content,
      child.typ == "math_display_inline",
      ctx.convert_katex,
    ),
  )
}

///|
fn block_token_to_shape(
  token : MdToken,
  ctx : ConvertContext,
) -> NormalizedShape {
  match token.typ {
    "front_matter" => front_matter_to_shape(token.content)
    "math_block" => math_block_token_to_shape(token, ctx.convert_katex)
    "paragraph" =>
      match paragraph_single_macro_math_shape(token, ctx) {
        Some(node) => node
        None => {
          let (nodes, node_gaps) = inline_tokens_to_shape_sequence(
            token.children,
            ctx,
          )
          make_tag_shape_with_sequence(token.tag, token.attrs, nodes, node_gaps)
        }
      }
    "heading" | "list_item" | "table_head_cell" | "table_cell" => {
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
