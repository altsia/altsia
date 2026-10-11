///|
priv struct VListElement {
  node : HtmlNode
  shift : Double
  margin_left : String?
  margin_right : String?
  wrapper_classes : Array[String]
  wrapper_style : Array[(String, String)]
}

///|
priv enum VListChild {
  VElem(VListElement)
  VKern(Double)
}

///|
fn vlist_elem(
  node : HtmlNode,
  shift? : Double = 0.0,
  margin_left? : String,
  margin_right? : String,
  wrapper_classes? : Array[String] = [],
  wrapper_style? : Array[(String, String)] = [],
) -> VListChild {
  VElem({
    node,
    shift,
    margin_left,
    margin_right,
    wrapper_classes,
    wrapper_style,
  })
}

///|
fn make_vlist(
  position_type : String,
  position_data : Double,
  children : Array[VListChild],
  _options : Options,
) -> HtmlNode {
  guard !children.is_empty() else { make_span(["vlist-t"], []) }
  let (children, depth) = if position_type == "individualShift" {
    let first = match children[0] {
      VElem(item) => item
      _ => abort("Expected vlist element")
    }
    let depth = -first.shift - first.node.depth
    let mut current = depth
    let mut previous = first
    let output : Array[VListChild] = [children[0]]
    for i = 1; i < children.length(); i = i + 1 {
      let item = match children[i] {
        VElem(item) => item
        _ => abort("Expected vlist element")
      }
      let diff = -item.shift - current - item.node.depth
      let size = diff - (previous.node.height + previous.node.depth)
      current = current + diff
      output.push(VKern(size))
      output.push(children[i])
      previous = item
    }
    (output, depth)
  } else if position_type == "top" {
    let mut bottom = position_data
    for child in children {
      bottom = bottom -
        (match child {
          VKern(size) => size
          VElem(item) => item.node.height + item.node.depth
        })
    }
    (children, bottom)
  } else if position_type == "bottom" {
    (children, -position_data)
  } else {
    let first = match children[0] {
      VElem(item) => item
      _ => abort("Expected vlist element")
    }
    (
      children,
      -first.node.depth -
      (if position_type == "shift" { position_data } else { 0.0 }),
    )
  }
  let mut pstrut_size = 0.0
  for child in children {
    if child is VElem(item) {
      pstrut_size = pstrut_size
        .max(item.node.max_font_size)
        .max(item.node.height)
    }
  }
  pstrut_size = pstrut_size + 2.0
  let pstrut = make_span(["pstrut"], [])
  pstrut.set_style("height", make_em(pstrut_size))
  let real_children : Array[HtmlNode] = []
  let mut min_pos = depth
  let mut max_pos = depth
  let mut current = depth
  for child in children {
    match child {
      VKern(size) => current = current + size
      VElem(item) => {
        let wrapper = make_span(item.wrapper_classes, [pstrut, item.node])
        for (key, value) in item.wrapper_style {
          wrapper.set_style(key, value)
        }
        wrapper.set_style(
          "top",
          make_em(-pstrut_size - current - item.node.depth),
        )
        if item.margin_left is Some(value) {
          wrapper.set_style("marginLeft", value)
        }
        if item.margin_right is Some(value) {
          wrapper.set_style("marginRight", value)
        }
        real_children.push(wrapper)
        current = current + (item.node.height + item.node.depth)
      }
    }
    min_pos = min_pos.min(current)
    max_pos = max_pos.max(current)
  }
  let vlist = make_span(["vlist"], real_children)
  vlist.set_style("height", make_em(max_pos))
  let rows = if min_pos < 0.0 {
    let depth_strut = make_span(["vlist"], [make_span([], [])])
    depth_strut.set_style("height", make_em(-min_pos))
    let top_strut = make_span(["vlist-s"], [
      html_node("symbol", text="\u{200b}"),
    ])
    [
      make_span(["vlist-r"], [vlist, top_strut]),
      make_span(["vlist-r"], [depth_strut]),
    ]
  } else {
    [make_span(["vlist-r"], [vlist])]
  }
  let table = make_span(
    if rows.length() == 2 {
      ["vlist-t", "vlist-t2"]
    } else {
      ["vlist-t"]
    },
    rows,
  )
  table.height = max_pos
  table.depth = -min_pos
  table
}

///|
fn make_line_span(
  class_name : String,
  options : Options,
  thickness? : Double,
) -> HtmlNode {
  let line = make_span([class_name], [], options~)
  let thickness = thickness.map_or(options.metric("defaultRuleThickness"), value => {
    if value != 0.0 {
      value
    } else {
      options.metric("defaultRuleThickness")
    }
  })
  line.height = thickness.max(options.min_rule_thickness)
  line.set_style("borderBottomWidth", make_em(line.height))
  line.max_font_size = 1.0
  line
}

///|
fn try_combine_chars(chars : Array[HtmlNode]) -> Unit {
  let mut i = 0
  while i + 1 < chars.length() {
    let previous = chars[i]
    let next = chars[i + 1]
    let compatible = previous.kind == "symbol" &&
      next.kind == "symbol" &&
      class_string(previous.classes) == class_string(next.classes) &&
      previous.skew == next.skew &&
      previous.max_font_size == next.max_font_size &&
      !(previous.italic != 0.0 && previous.has_class("mathnormal")) &&
      !(previous.classes.length() == 1 &&
      (previous.classes[0] == "mbin" || previous.classes[0] == "mord")) &&
      same_styles(previous.style, next.style)
    if compatible {
      previous.text = previous.text + next.text
      previous.height = previous.height.max(next.height)
      previous.depth = previous.depth.max(next.depth)
      previous.italic = next.italic
      let _ = chars.remove(i + 1)
    } else {
      i = i + 1
    }
  }
}

///|
fn same_styles(
  left : Array[(String, String)],
  right : Array[(String, String)],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for pair in left {
    if !right.contains(pair) {
      return false
    }
  }
  true
}
