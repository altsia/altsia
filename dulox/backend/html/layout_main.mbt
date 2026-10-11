///|
fn layout_wrap_fragment(node : HtmlNode, options : Options) -> HtmlNode {
  if node.kind == "fragment" {
    make_span([], [node], options~)
  } else {
    node
  }
}

///|
fn layout_character_box(node : @katex.ParseNode) -> Bool {
  match node {
    @katex.ParseNode::MathOrd(..) | TextOrd(..) | Atom(..) => true
    OrdGroup(body=[child], ..)
    | Color(body=[child], ..)
    | Font(body=child, ..) => layout_character_box(child)
    _ => false
  }
}

///|
fn render_layout_node(node : @katex.ParseNode, options : Options) -> HtmlNode? {
  match node {
    Sqrt(body~, index~, ..) => Some(layout_sqrt(body, index, options))
    GenFrac(
      numer~,
      denom~,
      continued~,
      has_bar_line~,
      bar_size~,
      left_delim~,
      right_delim~,
      mode~
    ) =>
      Some(
        layout_fraction(
          numer, denom, continued, has_bar_line, bar_size, left_delim, right_delim,
          mode, options,
        ),
      )
    SupSub(base~, sup~, sub~, ..) =>
      Some(layout_supsub(base, sup, sub, options))
    Op(content~, suppress_base_shift~, ..) =>
      Some(layout_op(content, suppress_base_shift, None, None, false, options))
    OperatorName(body~, ..) =>
      Some(layout_operator_name(body, None, None, false, options))
    Accent(label~, is_stretchy~, is_shifty~, base~, mode~, ..) =>
      Some(
        layout_accent(
          label,
          is_stretchy,
          is_shifty,
          base,
          mode,
          None,
          None,
          false,
          options,
        ),
      )
    AccentUnder(label~, base~, ..) =>
      Some(layout_accent_under(label, base, options))
    HorizBrace(label~, is_over~, base~, ..) =>
      Some(layout_horiz_brace(label, is_over, base, None, None, options))
    XArrow(label~, body~, below~, ..) =>
      Some(layout_xarrow(label, body, below, options))
    Overline(body~, ..) => Some(layout_line(body, true, options))
    Underline(body~, ..) => Some(layout_line(body, false, options))
    DelimSizing(delim~, size~, mclass~, mode~) =>
      Some(
        if delim == "." {
          make_span([atom_class(mclass)], [])
        } else {
          make_sized_delim(delim, size, options, mode, [atom_class(mclass)])
        },
      )
    Middle(delim~, mode~) => {
      let result = if delim == "." {
        make_null_delimiter(options, [])
      } else {
        make_sized_delim(delim, 1, options, mode, [])
      }
      if delim != "." {
        result.middle = Some((delim, options))
      }
      Some(result)
    }
    LeftRight(body~, left~, right~, right_color~, mode~) =>
      Some(layout_left_right(body, left, right, right_color, mode, options))
    LeftRightRight(delim~, color~, mode~) =>
      Some(
        if delim == "." {
          make_null_delimiter(options, ["mclose"])
        } else {
          make_sized_delim(
            delim,
            1,
            {
              ..options,
              color: if color is Some(_) {
                color
              } else {
                options.color
              },
            },
            mode,
            ["mclose"],
          )
        },
      )
    _ => None
  }
}

///|
fn layout_left_right(
  body : Array[@katex.ParseNode],
  left : String,
  right : String,
  right_color : String?,
  mode : @katex.Mode,
  options : Options,
) -> HtmlNode {
  let inner = build_expression(
    body,
    options,
    surrounding_left="mopen",
    surrounding_right="mclose",
  )
  let mut height = 0.0
  let mut depth = 0.0
  for node in inner {
    if node.middle is None {
      height = height.max(node.height)
      depth = depth.max(node.depth)
    }
  }
  height = height * options.size_multiplier
  depth = depth * options.size_multiplier
  let left_node = if left == "." {
    make_null_delimiter(options, ["mopen"])
  } else {
    make_left_right_delim(left, height, depth, options, mode, ["mopen"])
  }
  for i = 0; i < inner.length(); i = i + 1 {
    if inner[i].middle is Some((delim, middle_options)) {
      inner[i] = make_left_right_delim(
        delim,
        height,
        depth,
        middle_options,
        mode,
        [],
      )
    }
  }
  let right_options = right_color.map_or(options, color => {
    ..options,
    color: Some(color),
  })
  let right_node = if right == "." {
    make_null_delimiter(options, ["mclose"])
  } else {
    make_left_right_delim(right, height, depth, right_options, mode, ["mclose"])
  }
  make_span(["minner"], [left_node, ..inner, right_node], options~)
}

///|
fn layout_sqrt(
  body : @katex.ParseNode,
  index : @katex.ParseNode?,
  options : Options,
) -> HtmlNode {
  let inner = layout_wrap_fragment(
    build_group(body, options.with_style(style_cramp(options.style))),
    options,
  )
  if inner.height == 0.0 {
    inner.height = options.metric("xHeight")
  }
  let theta = options.metric("defaultRuleThickness")
  let phi = if options.style < 2 { options.metric("xHeight") } else { theta }
  let mut clearance = theta + phi / 4.0
  let (image, rule_width, advance) = make_sqrt_image(
    inner.height + inner.depth + clearance + theta,
    options,
  )
  let delim_depth = image.height - rule_width
  if delim_depth > inner.height + inner.depth + clearance {
    clearance = (clearance + delim_depth - inner.height - inner.depth) / 2.0
  }
  let image_shift = image.height - inner.height - clearance - rule_width
  inner.set_style("paddingLeft", make_em(advance))
  let body = make_vlist(
    "firstBaseline",
    0.0,
    [
      vlist_elem(inner, wrapper_classes=["svg-align"]),
      VKern(-(inner.height + image_shift)),
      vlist_elem(image),
      VKern(rule_width),
    ],
    options,
  )
  match index {
    None => make_span(["mord", "sqrt"], [body], options~)
    Some(index) => {
      let root = build_group(index, options.with_style(6), base_options=options)
      let root_vlist = make_vlist(
        "shift",
        -0.6 * (body.height - body.depth),
        [vlist_elem(root)],
        options,
      )
      make_span(
        ["mord", "sqrt"],
        [make_span(["katex-root"], [root_vlist]), body],
        options~,
      )
    }
  }
}

///|
fn layout_fraction(
  numer : @katex.ParseNode,
  denom : @katex.ParseNode,
  continued : Bool,
  has_bar : Bool,
  bar_size : @katex.Measurement?,
  left : String?,
  right : String?,
  mode : @katex.Mode,
  options : Options,
) -> HtmlNode {
  let numerator = build_group(
    numer,
    options.with_style(style_frac_num(options.style)),
    base_options=options,
  )
  if continued {
    numerator.height = numerator.height.max(8.5 / options.metric("ptPerEm"))
    numerator.depth = numerator.depth.max(3.5 / options.metric("ptPerEm"))
  }
  let denominator = build_group(
    denom,
    options.with_style(style_frac_den(options.style)),
    base_options=options,
  )
  let rule = if has_bar {
    Some(
      bar_size.map_or(make_line_span("frac-line", options), size => {
        make_line_span(
          "frac-line",
          options,
          thickness=calculate_size(size, options),
        )
      }),
    )
  } else {
    None
  }
  let rule_width = rule.map_or(0.0, line => line.height)
  let rule_spacing = rule.map_or(options.metric("defaultRuleThickness"), line => {
    line.height
  })
  let mut num_shift = if options.style / 2 == 0 {
    options.metric("num1")
  } else if rule_width > 0.0 {
    options.metric("num2")
  } else {
    options.metric("num3")
  }
  let clearance = if options.style / 2 == 0 {
    (if rule_width > 0.0 { 3.0 } else { 7.0 }) * rule_spacing
  } else {
    (if rule_width > 0.0 { 1.0 } else { 3.0 }) * rule_spacing
  }
  let mut den_shift = options.metric(
    if options.style / 2 == 0 {
      "denom1"
    } else {
      "denom2"
    },
  )
  let fraction = match rule {
    None => {
      let candidate = num_shift -
        numerator.depth -
        (denominator.height - den_shift)
      if candidate < clearance {
        num_shift = num_shift + 0.5 * (clearance - candidate)
        den_shift = den_shift + 0.5 * (clearance - candidate)
      }
      make_vlist(
        "individualShift",
        0.0,
        [
          vlist_elem(denominator, shift=den_shift),
          vlist_elem(numerator, shift=-num_shift),
        ],
        options,
      )
    }
    Some(rule) => {
      let axis = options.metric("axisHeight")
      if num_shift - numerator.depth - (axis + 0.5 * rule_width) < clearance {
        num_shift = num_shift +
          (
            clearance -
            (num_shift - numerator.depth - (axis + 0.5 * rule_width))
          )
      }
      if axis - 0.5 * rule_width - (denominator.height - den_shift) < clearance {
        den_shift = den_shift +
          (
            clearance -
            (axis - 0.5 * rule_width - (denominator.height - den_shift))
          )
      }
      make_vlist(
        "individualShift",
        0.0,
        [
          vlist_elem(denominator, shift=den_shift),
          vlist_elem(rule, shift=-(axis - 0.5 * rule_width)),
          vlist_elem(numerator, shift=-num_shift),
        ],
        options,
      )
    }
  }
  let new_options = options.with_style(options.style)
  let multiplier = new_options.size_multiplier / options.size_multiplier
  fraction.height = fraction.height * multiplier
  fraction.depth = fraction.depth * multiplier
  let delim_size = if options.style / 2 == 0 {
    options.metric("delim1")
  } else if options.style / 2 == 3 {
    options.with_style(4).metric("delim2")
  } else {
    options.metric("delim2")
  }
  let left_node = match left {
    None => make_null_delimiter(options, ["mopen"])
    Some(delim) =>
      make_custom_sized_delim(delim, delim_size, true, new_options, mode, [
        "mopen",
      ])
  }
  let right_node = if continued {
    make_span([], [])
  } else {
    match right {
      None => make_null_delimiter(options, ["mclose"])
      Some(delim) =>
        make_custom_sized_delim(delim, delim_size, true, new_options, mode, [
          "mclose",
        ])
    }
  }
  make_span(
    ["mord", ..new_options.sizing_classes(options)],
    [left_node, make_span(["mfrac"], [fraction]), right_node],
    options~,
  )
}

///|
fn layout_line(
  body : @katex.ParseNode,
  over : Bool,
  options : Options,
) -> HtmlNode {
  let inner = build_group(
    body,
    if over {
      options.with_style(style_cramp(options.style))
    } else {
      options
    },
  )
  let line = make_line_span(
    if over {
      "overline-line"
    } else {
      "underline-line"
    },
    options,
  )
  let thickness = options.metric("defaultRuleThickness")
  let list = if over {
    make_vlist(
      "firstBaseline",
      0.0,
      [
        vlist_elem(inner),
        VKern(3.0 * thickness),
        vlist_elem(line),
        VKern(thickness),
      ],
      options,
    )
  } else {
    make_vlist(
      "top",
      inner.height,
      [
        VKern(thickness),
        vlist_elem(line),
        VKern(3.0 * thickness),
        vlist_elem(inner),
      ],
      options,
    )
  }
  make_span(
    ["mord", if over { "katex-overline" } else { "katex-underline" }],
    [list],
    options~,
  )
}
