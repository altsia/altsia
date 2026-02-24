// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

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
fn make_attr_shape_with_node(
  name : String,
  value : NormalizedShape,
) -> NormalizedShape {
  App([Text(":\{name}"), value], [Space])
}

///|
priv struct ConvertContext {
  link_lambda_map : Map[String, String]
  footnote_ref_lambda_map : Map[String, String]
  footnote_item_lambda_names : Array[String]
  convert_katex : KatexConvertMode
}

///|
fn metadata_convert_context(convert_katex : KatexConvertMode) -> ConvertContext {
  ConvertContext::{
    link_lambda_map: Map::new(),
    footnote_ref_lambda_map: Map::new(),
    footnote_item_lambda_names: [],
    convert_katex,
  }
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
    let gap_before = if i - 1 < node_gaps.length() {
      node_gaps[i - 1]
    } else {
      Space
    }
    push_shape_arg(args, gaps, nodes[i], gap_before~)
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
fn make_tag_shape_with_sequence_tight_after_attrs(
  tag : String,
  attrs : Array[(String, String)],
  nodes : Array[NormalizedShape],
  node_gaps : Array[Gap],
) -> NormalizedShape {
  if nodes.is_empty() {
    return make_tag_shape_with_sequence(tag, attrs, nodes, node_gaps)
  }
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
  let first_gap = if attrs.is_empty() { Space } else { Tight }
  push_shape_arg(args, gaps, nodes[0], gap_before=first_gap)
  for i in 1..<nodes.length() {
    let gap_before = if i - 1 < node_gaps.length() {
      node_gaps[i - 1]
    } else {
      Space
    }
    push_shape_arg(args, gaps, nodes[i], gap_before~)
  }
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
fn metadata_item_to_shape(
  item : MdMetadataItem,
  ctx : ConvertContext,
) -> NormalizedShape {
  let args : Array[NormalizedShape] = [Text(":\{item.key}")]
  let gaps : Array[Gap] = []
  let (nodes, node_gaps) = inline_tokens_to_shape_sequence(
    item.value_tokens,
    ctx,
  )
  append_children_to_app(args, gaps, nodes, node_gaps)
  App(args, gaps)
}

///|
fn metadata_to_shape(
  items : Array[MdMetadataItem],
  convert_katex : KatexConvertMode,
) -> NormalizedShape? {
  if items.is_empty() {
    return None
  }
  let ctx = metadata_convert_context(convert_katex)
  let args : Array[NormalizedShape] = [Text("metadata")]
  let gaps : Array[Gap] = [Space]
  for item in items {
    push_shape_arg(
      args,
      gaps,
      metadata_item_to_shape(item, ctx),
      gap_before=Space,
    )
  }
  Some(App(args, gaps))
}

///|
