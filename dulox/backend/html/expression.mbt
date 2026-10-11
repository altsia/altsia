///|
fn build_expression(
  nodes : Array[@katex.ParseNode],
  options : Options,
  real_group? : Bool = true,
  root? : Bool = false,
  surrounding_left? : String = "leftmost",
  surrounding_right? : String = "rightmost",
) -> Array[HtmlNode] {
  let groups : Array[HtmlNode] = []
  for node in nodes {
    let output = build_group(node, options)
    if output.kind == "fragment" {
      for child in output.children {
        groups.push(child)
      }
    } else {
      groups.push(output)
    }
  }
  try_combine_chars(groups)
  guard real_group else { groups }
  let glue_options = match nodes {
    [Sizing(size~, ..)] => options.with_size(size)
    [Styling(style~, ..)] => options.with_style(style_id(style))
    _ => options
  }
  let visits : Array[(HtmlNode, Array[HtmlNode], Int)] = []
  collect_spacing_nodes(groups, visits)
  let left = make_span([surrounding_left], [])
  let right = make_span([surrounding_right], [])
  let mut previous = left
  for (node, _, _) in visits {
    if !node.has_class("mspace") {
      cancel_binary(previous, node)
      previous = node
    } else if root && node.has_class("katex-newline") {
      previous = make_span(["leftmost"], [])
    }
  }
  cancel_binary(previous, right)
  let insertions : Array[(Array[HtmlNode], Int, HtmlNode)] = []
  let mut previous = left
  let mut insert_parent = groups
  let mut insert_index = 0
  for (node, parent, index) in visits {
    if !node.has_class("mspace") {
      if implicit_glue(previous, node, glue_options) is Some(glue) {
        insertions.push((insert_parent, insert_index, glue))
      }
      previous = node
    } else if root && node.has_class("katex-newline") {
      previous = make_span(["leftmost"], [])
    }
    insert_parent = parent
    insert_index = index + 1
  }
  if implicit_glue(previous, right, glue_options) is Some(glue) {
    insertions.push((insert_parent, insert_index, glue))
  }
  // Applying insertions from right to left preserves each recorded index.
  for i = insertions.length() - 1; i >= 0; i = i - 1 {
    let (parent, index, glue) = insertions[i]
    parent.insert(index, glue)
  }
  groups
}

///|
fn collect_spacing_nodes(
  nodes : Array[HtmlNode],
  visits : Array[(HtmlNode, Array[HtmlNode], Int)],
) -> Unit {
  for index, node in nodes {
    if node.kind == "fragment" ||
      node.kind == "a" ||
      (node.kind == "span" && node.has_class("enclosing")) {
      collect_spacing_nodes(node.children, visits)
    } else {
      visits.push((node, nodes, index))
    }
  }
}

///|
fn node_class(node : HtmlNode) -> String {
  node.classes.get(0).unwrap_or("")
}

///|
fn cancel_binary(previous : HtmlNode, node : HtmlNode) -> Unit {
  let prev_type = node_class(previous)
  let current_type = node_class(node)
  let right_cancels = match current_type {
    "rightmost" | "mrel" | "mclose" | "mpunct" => true
    _ => false
  }
  let left_cancels = match prev_type {
    "leftmost" | "mbin" | "mopen" | "mrel" | "mop" | "mpunct" => true
    _ => false
  }
  if prev_type == "mbin" && right_cancels {
    previous.classes[0] = "mord"
  } else if current_type == "mbin" && left_cancels {
    node.classes[0] = "mord"
  }
}

///|
fn implicit_glue(
  previous : HtmlNode,
  node : HtmlNode,
  options : Options,
) -> HtmlNode? {
  let amount = @backend.math_spacing(
    node_class(previous),
    node_class(node),
    node.has_class("mtight"),
    { thin: "3", operator: "3", medium: "4", thick: "5", },
  )
  amount.map(amount => {
    make_glue(
      {
        number: match amount {
          "3" => 3.0
          "4" => 4.0
          _ => 5.0
        },
        unit: "mu",
      },
      options,
    )
  })
}
