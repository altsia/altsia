///|
fn delimiter_normalize(delim : String) -> String {
  match delim {
    "<" | "\\lt" | "⟨" => "\\langle"
    ">" | "\\gt" | "⟩" => "\\rangle"
    _ => delim
  }
}

///|
fn delimiter_sequence(delim : String) -> Int {
  match delim {
    "<"
    | ">"
    | "\\langle"
    | "\\rangle"
    | "/"
    | "\\backslash"
    | "\\lt"
    | "\\gt" => 0
    "("
    | "\\lparen"
    | ")"
    | "\\rparen"
    | "["
    | "\\lbrack"
    | "]"
    | "\\rbrack"
    | "\\{"
    | "\\lbrace"
    | "\\}"
    | "\\rbrace"
    | "\\lfloor"
    | "\\rfloor"
    | "⌊"
    | "⌋"
    | "\\lceil"
    | "\\rceil"
    | "⌈"
    | "⌉"
    | "\\surd" => 1
    _ => 2
  }
}

///|
fn delimiter_style_wrap(
  delim : HtmlNode,
  style : Int,
  options : Options,
  classes : Array[String],
) -> HtmlNode {
  let new_options = options.base_style(style)
  let span = make_span(
    classes + new_options.sizing_classes(options),
    [delim],
    options~,
  )
  let multiplier = new_options.size_multiplier / options.size_multiplier
  span.height = span.height * multiplier
  span.depth = span.depth * multiplier
  span.max_font_size = new_options.size_multiplier
  span
}

///|
fn delimiter_center(span : HtmlNode, options : Options, style : Int) -> Unit {
  let new_options = options.base_style(style)
  let shift = (1.0 - options.size_multiplier / new_options.size_multiplier) *
    options.metric("axisHeight")
  span.classes.push("delimcenter")
  span.set_style("top", make_em(shift))
  span.height = span.height - shift
  span.depth = span.depth + shift
}

///|
fn delimiter_small(
  delim : String,
  style : Int,
  center : Bool,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let text = make_symbol(delim, "Main-Regular", mode, options)
  let span = delimiter_style_wrap(text, style, options, classes)
  if center {
    delimiter_center(span, options, style)
  }
  span
}

///|
fn delimiter_large(
  delim : String,
  size : Int,
  center : Bool,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let inner = make_symbol(delim, "Size\{size}-Regular", mode, options)
  let span = delimiter_style_wrap(
    make_span(["delimsizing", "size\{size}"], [inner], options~),
    2,
    options,
    classes,
  )
  if center {
    delimiter_center(span, options, 2)
  }
  span
}

///|
fn delimiter_glyph(
  symbol : String,
  font : String,
  mode : @katex.Mode,
  options : Options,
) -> VListChild {
  let size_class = if font == "Size1-Regular" {
    "delim-size1"
  } else {
    "delim-size4"
  }
  vlist_elem(
    make_span(["delimsizinginner", size_class], [
      make_span([], [make_symbol(symbol, font, mode, options)]),
    ]),
  )
}

///|
fn delimiter_inner(
  ch : String,
  height : Double,
  options : Options,
) -> VListChild {
  let glyph = make_symbol(ch, "Size4-Regular", @katex.Mode::Math, options)
  let width = if glyph.width != 0.0 {
    glyph.width
  } else {
    make_symbol(ch, "Size1-Regular", @katex.Mode::Math, options).width
  }
  let view_height = (1000.0 * height).round()
  let svg = make_svg([make_path(inner_delim_path(ch, view_height))], [
    ("width", make_em(width)),
    ("height", make_em(height)),
    ("style", "width:" + make_em(width)),
    ("viewBox", "0 0 \{1000.0 * width} \{view_height}"),
    ("preserveAspectRatio", "xMinYMin"),
  ])
  let span = make_svg_span([], [svg], options)
  span.height = height
  span.set_style("height", make_em(height))
  span.set_style("width", make_em(width))
  vlist_elem(span)
}

///|
fn delimiter_stacked(
  delim : String,
  height : Double,
  center : Bool,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let (top, middle, repeat, bottom, font, label, width) = match delim {
    "\\uparrow" => (delim, None, "⏐", "⏐", "Size1-Regular", "", 0.0)
    "\\Uparrow" => (delim, None, "‖", "‖", "Size1-Regular", "", 0.0)
    "\\downarrow" => ("⏐", None, "⏐", delim, "Size1-Regular", "", 0.0)
    "\\Downarrow" => ("‖", None, "‖", delim, "Size1-Regular", "", 0.0)
    "\\updownarrow" =>
      ("\\uparrow", None, "⏐", "\\downarrow", "Size1-Regular", "", 0.0)
    "\\Updownarrow" =>
      ("\\Uparrow", None, "‖", "\\Downarrow", "Size1-Regular", "", 0.0)
    "|" | "\\lvert" | "\\rvert" | "\\vert" =>
      (delim, None, "∣", delim, "Size1-Regular", "vert", 333.0)
    "\\|" | "\\lVert" | "\\rVert" | "\\Vert" =>
      (delim, None, "∥", delim, "Size1-Regular", "doublevert", 556.0)
    "[" | "\\lbrack" =>
      ("⎡", None, "⎢", "⎣", "Size4-Regular", "lbrack", 667.0)
    "]" | "\\rbrack" =>
      ("⎤", None, "⎥", "⎦", "Size4-Regular", "rbrack", 667.0)
    "\\lfloor" | "⌊" =>
      ("⎢", None, "⎢", "⎣", "Size4-Regular", "lfloor", 667.0)
    "\\lceil" | "⌈" =>
      ("⎡", None, "⎢", "⎢", "Size4-Regular", "lceil", 667.0)
    "\\rfloor" | "⌋" =>
      ("⎥", None, "⎥", "⎦", "Size4-Regular", "rfloor", 667.0)
    "\\rceil" | "⌉" =>
      ("⎤", None, "⎥", "⎥", "Size4-Regular", "rceil", 667.0)
    "(" | "\\lparen" =>
      ("⎛", None, "⎜", "⎝", "Size4-Regular", "lparen", 875.0)
    ")" | "\\rparen" =>
      ("⎞", None, "⎟", "⎠", "Size4-Regular", "rparen", 875.0)
    "\\{" | "\\lbrace" =>
      ("⎧", Some("⎨"), "⎪", "⎩", "Size4-Regular", "", 0.0)
    "\\}" | "\\rbrace" =>
      ("⎫", Some("⎬"), "⎪", "⎭", "Size4-Regular", "", 0.0)
    "\\lgroup" | "⟮" => ("⎧", None, "⎪", "⎩", "Size4-Regular", "", 0.0)
    "\\rgroup" | "⟯" => ("⎫", None, "⎪", "⎭", "Size4-Regular", "", 0.0)
    "\\lmoustache" | "⎰" =>
      ("⎧", None, "⎪", "⎭", "Size4-Regular", "", 0.0)
    "\\rmoustache" | "⎱" =>
      ("⎫", None, "⎪", "⎩", "Size4-Regular", "", 0.0)
    _ => (delim, None, delim, delim, "Size1-Regular", "", 0.0)
  }
  let top_glyph = make_symbol(top, font, mode, options)
  let repeat_glyph = make_symbol(repeat, font, mode, options)
  let bottom_glyph = make_symbol(bottom, font, mode, options)
  let top_height = top_glyph.height + top_glyph.depth
  let repeat_height = repeat_glyph.height + repeat_glyph.depth
  let bottom_height = bottom_glyph.height + bottom_glyph.depth
  let middle_height = middle.map_or(0.0, text => {
    let glyph = make_symbol(text, font, mode, options)
    glyph.height + glyph.depth
  })
  let factor = if middle is Some(_) { 2.0 } else { 1.0 }
  let min_height = top_height + bottom_height + middle_height
  let repeat_count = ((height - min_height) / (factor * repeat_height))
    .ceil()
    .max(0.0)
  let real_height = min_height + repeat_count * factor * repeat_height
  let axis = options.metric("axisHeight") *
    (if center { options.size_multiplier } else { 1.0 })
  let depth = real_height / 2.0 - axis
  let stack : Array[VListChild] = []
  if label != "" {
    let view_height = (real_height * 1000.0).round()
    let svg = make_svg(
      [
        make_path(
          tall_delim_path(
            label,
            ((real_height - top_height - bottom_height) * 1000.0).round(),
          ),
        ),
      ],
      [
        ("width", make_em(width / 1000.0)),
        ("height", make_em(view_height / 1000.0)),
        ("viewBox", "0 0 \{width} \{view_height}"),
      ],
    )
    let wrapper = make_svg_span([], [svg], options)
    wrapper.height = view_height / 1000.0
    wrapper.set_style("width", make_em(width / 1000.0))
    wrapper.set_style("height", make_em(view_height / 1000.0))
    stack.push(vlist_elem(wrapper))
  } else {
    stack.push(delimiter_glyph(bottom, font, mode, options))
    stack.push(VKern(-0.008))
    match middle {
      None =>
        stack.push(
          delimiter_inner(
            repeat,
            real_height - top_height - bottom_height + 0.016,
            options,
          ),
        )
      Some(middle) => {
        let inner_height = (
            real_height - top_height - bottom_height - middle_height
          ) /
          2.0 +
          0.016
        stack.push(delimiter_inner(repeat, inner_height, options))
        stack.push(VKern(-0.008))
        stack.push(delimiter_glyph(middle, font, mode, options))
        stack.push(VKern(-0.008))
        stack.push(delimiter_inner(repeat, inner_height, options))
      }
    }
    stack.push(VKern(-0.008))
    stack.push(delimiter_glyph(top, font, mode, options))
  }
  let new_options = options.base_style(2)
  let inner = make_vlist("bottom", depth, stack, new_options)
  delimiter_style_wrap(
    make_span(["delimsizing", "mult"], [inner], options=new_options),
    2,
    options,
    classes,
  )
}

///|
fn delimiter_choose(
  delim : String,
  height : Double,
  options : Options,
) -> (String, Int) {
  let sequence = delimiter_sequence(delim)
  let start = if 3 - options.style / 2 < 2 { 3 - options.style / 2 } else { 2 }
  for i = start; i < (if sequence == 2 { 3 } else { 7 }); i = i + 1 {
    let font = if i < 3 { "Main-Regular" } else { "Size\{i - 2}-Regular" }
    let glyph = make_symbol(delim, font, @katex.Mode::Math, options)
    let total = (glyph.height + glyph.depth) *
      (if i < 3 { options.base_style(6 - 2 * i).size_multiplier } else { 1.0 })
    if total > height {
      return if i < 3 { ("small", 6 - 2 * i) } else { ("large", i - 2) }
    }
  }
  if sequence == 0 {
    ("large", 4)
  } else {
    ("stack", 0)
  }
}

///|
fn make_sized_delim(
  delim : String,
  size : Int,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let delim = delimiter_normalize(delim)
  if delimiter_sequence(delim) == 2 {
    delimiter_stacked(
      delim,
      [0.0, 1.2, 1.8, 2.4, 3.0][size],
      false,
      options,
      mode,
      classes,
    )
  } else {
    delimiter_large(delim, size, false, options, mode, classes)
  }
}

///|
fn make_custom_sized_delim(
  delim : String,
  height : Double,
  center : Bool,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let delim = delimiter_normalize(delim)
  let (kind, size) = delimiter_choose(delim, height, options)
  match kind {
    "small" => delimiter_small(delim, size, center, options, mode, classes)
    "large" => delimiter_large(delim, size, center, options, mode, classes)
    _ => delimiter_stacked(delim, height, center, options, mode, classes)
  }
}

///|
fn make_left_right_delim(
  delim : String,
  height : Double,
  depth : Double,
  options : Options,
  mode : @katex.Mode,
  classes : Array[String],
) -> HtmlNode {
  let axis = options.metric("axisHeight") * options.size_multiplier
  let dist = (height - axis).max(depth + axis)
  let total = (dist / 500.0 * 901.0).max(
    2.0 * dist - 5.0 / options.metric("ptPerEm"),
  )
  make_custom_sized_delim(delim, total, true, options, mode, classes)
}

///|
fn make_sqrt_image(
  height : Double,
  options : Options,
) -> (HtmlNode, Double, Double) {
  let new_options = options.base_sizing()
  let (kind, size) = delimiter_choose(
    "\\surd",
    height * new_options.size_multiplier,
    new_options,
  )
  let mut multiplier = new_options.size_multiplier
  let extra = (options.min_rule_thickness - options.metric("sqrtRuleThickness")).max(
    0.0,
  )
  let (name, span_height, tex_height, view_height, min_width, advance) = if kind ==
    "small" {
    if height < 1.0 {
      multiplier = 1.0
    } else if height < 1.4 {
      multiplier = 0.7
    }
    (
      "sqrtMain",
      (1.0 + extra + 0.08) / multiplier,
      (1.0 + extra) / multiplier,
      1000.0 + 1000.0 * extra + 80.0,
      "0.853em",
      0.833 / multiplier,
    )
  } else if kind == "large" {
    let max_height = [0.0, 1.2, 1.8, 2.4, 3.0][size]
    (
      "sqrtSize\{size}",
      (max_height + extra + 0.08) / multiplier,
      (max_height + extra) / multiplier,
      1080.0 * max_height,
      "1.02em",
      1.0 / multiplier,
    )
  } else {
    (
      "sqrtTall",
      height + extra + 0.08,
      height + extra,
      (1000.0 * height + extra).floor() + 80.0,
      "0.742em",
      1.056,
    )
  }
  let svg = make_svg([make_path(sqrt_path(name, extra, view_height))], [
    ("width", "400em"),
    ("height", make_em(span_height)),
    ("viewBox", "0 0 400000 \{view_height}"),
    ("preserveAspectRatio", "xMinYMin slice"),
  ])
  let span = make_svg_span(["hide-tail"], [svg], options)
  span.height = tex_height
  span.set_style("minWidth", min_width)
  span.set_style("height", make_em(span_height))
  (span, (options.metric("sqrtRuleThickness") + extra) * multiplier, advance)
}
