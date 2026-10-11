///|
fn layout_atom_type(node : HtmlNode) -> String {
  if node.kind == "fragment" || node.kind == "a" {
    if node.children.last() is Some(child) {
      return layout_atom_type(child)
    }
  }
  match node.classes.get(0).unwrap_or("mord") {
    "mord"
    | "mop"
    | "mbin"
    | "mrel"
    | "mopen"
    | "mclose"
    | "mpunct"
    | "minner" as atom => atom
    _ => "mord"
  }
}

///|
fn layout_script_element(
  node : HtmlNode,
  shift : Double,
  left : String,
  right : String,
) -> VListChild {
  if left == "" {
    vlist_elem(node, shift~, margin_right=right)
  } else {
    vlist_elem(node, shift~, margin_left=left, margin_right=right)
  }
}

///|
fn layout_supsub(
  base : @katex.ParseNode?,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  options : Options,
) -> HtmlNode {
  if base is Some(node) {
    match node {
      Op(content~, limits~, always_handle_sup_sub~, suppress_base_shift~, ..) if limits &&
        (options.style / 2 == 0 || always_handle_sup_sub) =>
        return layout_op(content, suppress_base_shift, sup, sub, true, options)
      OperatorName(body~, always_handle_sup_sub~, limits~, ..) if always_handle_sup_sub &&
        (options.style / 2 == 0 || limits) =>
        return layout_operator_name(body, sup, sub, true, options)
      Accent(label~, is_stretchy~, is_shifty~, base=inner, mode~, ..) if layout_character_box(
          inner,
        ) =>
        return layout_accent(
          label, is_stretchy, is_shifty, inner, mode, sup, sub, true, options,
        )
      HorizBrace(label~, is_over~, base=inner, ..) if (sub is None) == is_over =>
        return layout_horiz_brace(label, is_over, inner, sup, sub, options)
      _ => ()
    }
  }
  let base_node = base.map_or(make_span([], []), value => {
    build_group(value, options)
  })
  let is_char = base.map_or(false, layout_character_box)
  let mut sup_shift = 0.0
  let mut sub_shift = 0.0
  let sup_node = sup.map(value => {
    let next = options.with_style(style_sup(options.style))
    let node = build_group(value, next, base_options=options)
    if !is_char {
      sup_shift = base_node.height -
        next.metric("supDrop") * next.size_multiplier / options.size_multiplier
    }
    node
  })
  let sub_node = sub.map(value => {
    let next = options.with_style(style_sub(options.style))
    let node = build_group(value, next, base_options=options)
    if !is_char {
      sub_shift = base_node.depth +
        next.metric("subDrop") * next.size_multiplier / options.size_multiplier
    }
    node
  })
  let min_sup = options.metric(
    if options.style == 0 {
      "sup1"
    } else if options.style % 2 == 1 {
      "sup3"
    } else {
      "sup2"
    },
  )
  let right = make_em(0.5 / options.metric("ptPerEm") / options.size_multiplier)
  let is_oval = base
    is Some(
      Op(
        content=@katex.OperatorContent::SymbolOperator("\\oiint" | "\\oiiint"),
        ..
      )
    )
  let left = if base_node.kind == "symbol" || is_oval {
    make_em(-base_node.italic)
  } else {
    ""
  }
  let x_height = options.metric("xHeight")
  let scripts = match (sup_node, sub_node) {
    (Some(upper), Some(lower)) => {
      sup_shift = sup_shift.max(min_sup).max(upper.depth + 0.25 * x_height)
      sub_shift = sub_shift.max(options.metric("sub2"))
      let max_width = 4.0 * options.metric("defaultRuleThickness")
      if sup_shift - upper.depth - (lower.height - sub_shift) < max_width {
        sub_shift = max_width - (sup_shift - upper.depth) + lower.height
        let psi = 0.8 * x_height - (sup_shift - upper.depth)
        if psi > 0.0 {
          sup_shift = sup_shift + psi
          sub_shift = sub_shift - psi
        }
      }
      make_vlist(
        "individualShift",
        0.0,
        [
          layout_script_element(lower, sub_shift, left, right),
          vlist_elem(upper, shift=-sup_shift, margin_right=right),
        ],
        options,
      )
    }
    (None, Some(lower)) => {
      sub_shift = sub_shift
        .max(options.metric("sub1"))
        .max(lower.height - 0.8 * x_height)
      make_vlist(
        "shift",
        sub_shift,
        [layout_script_element(lower, 0.0, left, right)],
        options,
      )
    }
    (Some(upper), None) => {
      sup_shift = sup_shift.max(min_sup).max(upper.depth + 0.25 * x_height)
      make_vlist(
        "shift",
        -sup_shift,
        [vlist_elem(upper, margin_right=right)],
        options,
      )
    }
    (None, None) => return base_node
  }
  make_span(
    [layout_atom_type(base_node)],
    [base_node, make_span(["msupsub"], [scripts])],
    options~,
  )
}

///|
fn layout_op(
  content : @katex.OperatorContent,
  suppress_shift : Bool,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  limits : Bool,
  options : Options,
) -> HtmlNode {
  let base = match content {
    SymbolOperator(name) => {
      let large = options.style / 2 == 0 && name != "\\smallint"
      let font = if large { "Size2-Regular" } else { "Size1-Regular" }
      let glyph_name = match name {
        "\\oiint" => "\\iint"
        "\\oiiint" => "\\iiint"
        _ => name
      }
      let symbol = make_symbol(glyph_name, font, @katex.Mode::Math, options, classes=[
        "mop",
        "op-symbol",
        if large {
          "large-op"
        } else {
          "small-op"
        },
      ])
      if name == "\\oiint" || name == "\\oiiint" {
        let oval_name = (if name == "\\oiint" {
            "oiintSize"
          } else {
            "oiiintSize"
          }) +
          (if large { "2" } else { "1" })
        let oval = static_svg(oval_name, options)
        let wrapped = make_vlist(
          "individualShift",
          0.0,
          [
            vlist_elem(symbol, shift=0.0),
            vlist_elem(oval, shift=if large { 0.08 } else { 0.0 }),
          ],
          options,
        )
        wrapped.classes = ["mop", ..wrapped.classes]
        wrapped.italic = symbol.italic
        wrapped
      } else {
        symbol
      }
    }
    BodyOperator(body) => {
      let inner = build_expression(body, options)
      if inner is [single] && single.kind == "symbol" {
        single.classes[0] = "mop"
        single
      } else {
        make_span(["mop"], inner, options~)
      }
    }
    NamedOperator(name) => {
      let name = name.strip_prefix("\\").map_or(name, StringView::to_owned)
      let children : Array[HtmlNode] = []
      for ch in name {
        children.push(
          make_math_symbol(
            String::from_array([ch]),
            @katex.Mode::Math,
            options,
            [],
          ),
        )
      }
      make_span(["mop"], children, options~)
    }
  }
  let oval = match content {
    SymbolOperator("\\oiint" | "\\oiiint") => true
    _ => false
  }
  let shift = if (base.kind == "symbol" || oval) && !suppress_shift {
    (base.height - base.depth) / 2.0 - options.metric("axisHeight")
  } else {
    0.0
  }
  let slant = if (base.kind == "symbol" || oval) && !suppress_shift {
    base.italic
  } else {
    0.0
  }
  if limits {
    layout_limits(base, sup, sub, slant, shift, options)
  } else {
    if shift != 0.0 {
      base.set_style("position", "relative")
      base.set_style("top", make_em(shift))
    }
    base
  }
}

///|
fn layout_operator_name(
  body : Array[@katex.ParseNode],
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  limits : Bool,
  options : Options,
) -> HtmlNode {
  let converted = body.map(node => {
    match node {
      @katex.ParseNode::MathOrd(text~, mode~, ..)
      | TextOrd(text~, mode~, ..)
      | Atom(text~, mode~, ..)
      | Spacing(text~, mode~, ..)
      | AccentToken(text~, mode~, ..)
      | OperatorToken(text~, mode~, ..) =>
        @katex.ParseNode::TextOrd(mode~, text~, loc=None)
      _ => node
    }
  })
  let expression = build_expression(converted, { ..options, font: "mathrm", })
  for child in expression {
    if child.kind == "symbol" {
      child.text = child.text
        .replace(old="−", new="-")
        .replace(old="∗", new="*")
    }
  }
  let base = make_span(["mop"], expression, options~)
  if limits {
    layout_limits(base, sup, sub, 0.0, 0.0, options)
  } else {
    base
  }
}

///|
fn layout_limits(
  base : HtmlNode,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  slant : Double,
  base_shift : Double,
  options : Options,
) -> HtmlNode {
  let base = make_span([], [base])
  let sub_single = sub.map_or(false, layout_character_box)
  let upper = sup.map(node => {
    let elem = build_group(
      node,
      options.with_style(style_sup(options.style)),
      base_options=options,
    )
    (
      elem,
      options
      .metric("bigOpSpacing1")
      .max(options.metric("bigOpSpacing3") - elem.depth),
    )
  })
  let lower = sub.map(node => {
    let elem = build_group(
      node,
      options.with_style(style_sub(options.style)),
      base_options=options,
    )
    (
      elem,
      options
      .metric("bigOpSpacing2")
      .max(options.metric("bigOpSpacing4") - elem.height),
    )
  })
  let spacing = options.metric("bigOpSpacing5")
  let group = match (upper, lower) {
    (Some((upper, upper_kern)), Some((lower, lower_kern))) => {
      let bottom = spacing +
        lower.height +
        lower.depth +
        lower_kern +
        base.depth +
        base_shift
      make_vlist(
        "bottom",
        bottom,
        [
          VKern(spacing),
          vlist_elem(lower, margin_left=make_em(-slant)),
          VKern(lower_kern),
          vlist_elem(base),
          VKern(upper_kern),
          vlist_elem(upper, margin_left=make_em(slant)),
          VKern(spacing),
        ],
        options,
      )
    }
    (None, Some((lower, kern))) =>
      make_vlist(
        "top",
        base.height - base_shift,
        [
          VKern(spacing),
          vlist_elem(lower, margin_left=make_em(-slant)),
          VKern(kern),
          vlist_elem(base),
        ],
        options,
      )
    (Some((upper, kern)), None) =>
      make_vlist(
        "bottom",
        base.depth + base_shift,
        [
          vlist_elem(base),
          VKern(kern),
          vlist_elem(upper, margin_left=make_em(slant)),
          VKern(spacing),
        ],
        options,
      )
    (None, None) => return base
  }
  let parts : Array[HtmlNode] = []
  if lower is Some(_) && slant != 0.0 && !sub_single {
    let spacer = make_span(["mspace"], [], options~)
    spacer.set_style("marginRight", make_em(slant))
    parts.push(spacer)
  }
  parts.push(group)
  make_span(["mop", "op-limits"], parts, options~)
}
