///|
fn layout_base_skew(node : HtmlNode) -> Double {
  if node.kind == "symbol" {
    return node.skew
  }
  if node.children is [child] {
    layout_base_skew(child)
  } else {
    0.0
  }
}

///|
fn layout_accent(
  label : String,
  stretchy : Bool,
  shifty : Bool,
  base : @katex.ParseNode,
  mode : @katex.Mode,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  has_scripts : Bool,
  options : Options,
) -> HtmlNode {
  let scripts = if has_scripts {
    Some(layout_supsub(Some(base), sup, sub, options))
  } else {
    None
  }
  let body = build_group(base, options.with_style(style_cramp(options.style)))
  let skew = if shifty && layout_character_box(base) {
    layout_base_skew(body)
  } else {
    0.0
  }
  let below = label == "\\c"
  let mut clearance = if below {
    body.height + body.depth
  } else {
    body.height.min(options.metric("xHeight"))
  }
  let accent_body = if !stretchy {
    let (accent, width) = if label == "\\vec" {
      (static_svg("vec", options), 0.471)
    } else {
      let accent = make_ord(
        @katex.ParseNode::TextOrd(mode~, text=label, loc=None),
        options,
      )
      accent.italic = 0.0
      if below {
        clearance = clearance + accent.depth
      }
      (accent, accent.width)
    }
    let accent_body = make_span(["accent-body"], [accent])
    let full = label == "\\textcircled"
    if full {
      accent_body.classes.push("accent-full")
      clearance = body.height
    }
    accent_body.set_style(
      "left",
      make_em(if full { skew } else { skew - width / 2.0 }),
    )
    if full {
      accent_body.set_style("top", ".2em")
    }
    make_vlist(
      "firstBaseline",
      0.0,
      [vlist_elem(body), VKern(-clearance), vlist_elem(accent_body)],
      options,
    )
  } else {
    let accent_body = stretchy_svg(label, Some(base), options)
    let wrapper_style : Array[(String, String)] = if skew > 0.0 {
      [
        ("width", "calc(100% - " + make_em(2.0 * skew) + ")"),
        ("marginLeft", make_em(2.0 * skew)),
      ]
    } else {
      []
    }
    make_vlist(
      "firstBaseline",
      0.0,
      [
        vlist_elem(body),
        vlist_elem(accent_body, wrapper_classes=["svg-align"], wrapper_style~),
      ],
      options,
    )
  }
  let result = make_span(["mord", "katex-accent"], [accent_body], options~)
  match scripts {
    None => result
    Some(scripts) => {
      scripts.children[0] = result
      scripts.height = scripts.height.max(result.height)
      scripts.classes[0] = "mord"
      scripts
    }
  }
}

///|
fn layout_accent_under(
  label : String,
  base : @katex.ParseNode,
  options : Options,
) -> HtmlNode {
  let inner = build_group(base, options)
  let accent = stretchy_svg(label, Some(base), options)
  let kern = if label == "\\utilde" { 0.12 } else { 0.0 }
  let vlist = make_vlist(
    "top",
    inner.height,
    [
      vlist_elem(accent, wrapper_classes=["svg-align"]),
      VKern(kern),
      vlist_elem(inner),
    ],
    options,
  )
  make_span(["mord", "accentunder"], [vlist], options~)
}

///|
fn layout_horiz_brace(
  label : String,
  over : Bool,
  base : @katex.ParseNode,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  options : Options,
) -> HtmlNode {
  let scripts = match (sup, sub) {
    (Some(node), _) =>
      Some(
        build_group(
          node,
          options.with_style(style_sup(options.style)),
          base_options=options,
        ),
      )
    (_, Some(node)) =>
      Some(
        build_group(
          node,
          options.with_style(style_sub(options.style)),
          base_options=options,
        ),
      )
    _ => None
  }
  let body = build_group(base, options.base_style(0))
  let brace = stretchy_svg(label, Some(base), options)
  let mut vlist = if over {
    make_vlist(
      "firstBaseline",
      0.0,
      [
        vlist_elem(body),
        VKern(0.1),
        vlist_elem(brace, wrapper_classes=["svg-align"]),
      ],
      options,
    )
  } else {
    make_vlist(
      "bottom",
      body.depth + 0.1 + brace.height,
      [
        vlist_elem(brace, wrapper_classes=["svg-align"]),
        VKern(0.1),
        vlist_elem(body),
      ],
      options,
    )
  }
  if scripts is Some(scripts) {
    let wrapped = make_span(
      ["minner", if over { "mover" } else { "munder" }],
      [vlist],
      options~,
    )
    vlist = if over {
      make_vlist(
        "firstBaseline",
        0.0,
        [vlist_elem(wrapped), VKern(0.2), vlist_elem(scripts)],
        options,
      )
    } else {
      make_vlist(
        "bottom",
        wrapped.depth + 0.2 + scripts.height + scripts.depth,
        [vlist_elem(scripts), VKern(0.2), vlist_elem(wrapped)],
        options,
      )
    }
  }
  make_span(
    ["minner", if over { "mover" } else { "munder" }],
    [vlist],
    options~,
  )
}

///|
fn layout_xarrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
  options : Options,
) -> HtmlNode {
  // The parser uses a required empty body for CD's unlabeled equals arrow.
  let upper = if label == "\\\\cdlongequal" &&
    body is @katex.OrdGroup(body=[], ..) {
    make_span([], [])
  } else {
    layout_wrap_fragment(
      build_group(
        body,
        options.with_style(style_sup(options.style)),
        base_options=options,
      ),
      options,
    )
  }
  let prefix = if label.has_prefix("\\x") { "x" } else { "cd" }
  upper.classes.push(prefix + "-arrow-pad")
  let lower = below.map(node => {
    let built = layout_wrap_fragment(
      build_group(
        node,
        options.with_style(style_sub(options.style)),
        base_options=options,
      ),
      options,
    )
    built.classes.push(prefix + "-arrow-pad")
    built
  })
  let arrow = stretchy_svg(label, None, options)
  let axis = options.metric("axisHeight")
  let arrow_shift = -axis + 0.5 * arrow.height
  let upper_shift = -axis -
    0.5 * arrow.height -
    0.111 -
    (if upper.depth > 0.25 || label == "\\xleftequilibrium" {
      upper.depth
    } else {
      0.0
    })
  let children = [
    vlist_elem(upper, shift=upper_shift),
    vlist_elem(arrow, shift=arrow_shift, wrapper_classes=["svg-align"]),
  ]
  if lower is Some(lower) {
    children.push(
      vlist_elem(lower, shift=-axis + lower.height + 0.5 * arrow.height + 0.111),
    )
  }
  let vlist = make_vlist("individualShift", 0.0, children, options)
  make_span(["mrel", "x-arrow"], [vlist], options~)
}
