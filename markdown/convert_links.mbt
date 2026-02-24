// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

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
fn build_convert_context(
  document : MdDocument,
  convert_katex : KatexConvertMode,
) -> ConvertContext {
  let link_lambda_map : Map[String, String] = Map::new()
  for entry in document.link_references.to_array() {
    let item = entry.1
    link_lambda_map[item.label] = item.label
  }
  let footnote_ref_lambda_map : Map[String, String] = Map::new()
  let footnote_item_lambda_names : Array[String] = []
  for i in 0..<document.footnotes.length() {
    let item = document.footnotes[i]
    footnote_ref_lambda_map[item.label] = make_footnote_ref_lambda_name(i + 1)
    footnote_item_lambda_names.push(make_footnote_item_lambda_name(i + 1))
  }
  ConvertContext::{
    link_lambda_map,
    footnote_ref_lambda_map,
    footnote_item_lambda_names,
    convert_katex,
  }
}

///|
fn make_link_lambda_shape(name : String, href : String) -> NormalizedShape {
  let normalized_href = if is_local_link(href) {
    rewrite_local_link_url(href)
  } else {
    href
  }
  make_lambda_shape(name, [], [Text(normalized_href)])
}

///|
fn make_footnote_ref_lambda_shape(
  name : String,
  anchor_id : String,
  display_index : Int,
) -> NormalizedShape {
  let link_node = make_tag_shape_with_sequence_tight_after_attrs(
    "a",
    [("href", "#\{anchor_id}")],
    [Text(display_index.to_string())],
    [],
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
  let (nodes, node_gaps) = inline_tokens_to_shape_sequence(
    footnote.value_tokens,
    ctx,
  )
  let body = make_tag_shape_with_sequence_tight_after_attrs(
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
  for entry in document.link_references.to_array() {
    let item = entry.1
    declarations.push(make_link_lambda_shape(item.label, item.href))
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
  Some(
    make_tag_shape_with_children("section", [("class", "footnotes")], [
      list_node,
    ]),
  )
}
