///|
fn static_svg(value : String, options : Options) -> HtmlNode {
  let (width, height) = match value {
    "vec" => (0.471, 0.714)
    "oiintSize1" => (0.957, 0.499)
    "oiintSize2" => (1.472, 0.659)
    "oiiintSize1" => (1.304, 0.499)
    "oiiintSize2" => (1.98, 0.659)
    _ => (0.0, 0.0)
  }
  let svg = make_svg([make_path(svg_path(value))], [
    ("width", make_em(width)),
    ("height", make_em(height)),
    ("style", "width:" + make_em(width)),
    ("viewBox", "0 0 \{1000.0 * width} \{1000.0 * height}"),
    ("preserveAspectRatio", "xMinYMin"),
  ])
  let span = make_svg_span(["katex-overlay"], [svg], options)
  span.height = height
  span.set_style("height", make_em(height))
  span.set_style("width", make_em(width))
  span
}

///|
fn stretchy_svg(
  label : String,
  base : @katex.ParseNode?,
  options : Options,
) -> HtmlNode {
  let label = label.strip_prefix("\\").map_or(label, StringView::to_owned)
  if ["widehat", "widecheck", "widetilde", "utilde"].contains(label) {
    let count = if base is Some(@katex.ParseNode::OrdGroup(body~, ..)) {
      body.length()
    } else {
      1
    }
    let wide_hat = label == "widehat" || label == "widecheck"
    let index = if count > 5 { 4 } else { [1, 1, 2, 2, 3, 3][count] }
    let view_width : Double = if wide_hat {
      [0.0, 1062.0, 2364.0, 2364.0, 2364.0][index]
    } else {
      [0.0, 600.0, 1033.0, 2339.0, 2340.0][index]
    }
    let view_height : Double = if wide_hat {
      [0.0, 239.0, 300.0, 360.0, 420.0][index]
    } else {
      [0.0, 260.0, 286.0, 306.0, 312.0][index]
    }
    let height = if count > 5 {
      if wide_hat {
        0.42
      } else {
        0.34
      }
    } else if wide_hat {
      [0.0, 0.24, 0.3, 0.3, 0.36, 0.42][index]
    } else {
      [0.0, 0.26, 0.286, 0.3, 0.306, 0.34][index]
    }
    let name = (if wide_hat { label } else { "tilde" }) + index.to_string()
    let svg = make_svg([make_path(svg_path(name))], [
      ("width", "100%"),
      ("height", make_em(height)),
      ("viewBox", "0 0 \{view_width} \{view_height}"),
      ("preserveAspectRatio", "none"),
    ])
    let span = make_svg_span([], [svg], options)
    span.height = height
    span.set_style("height", make_em(height))
    return span
  }
  let (paths, min_width, view_height, align) = stretchy_image_data(label)
  let height = view_height / 1000.0
  let count = paths.length()
  let (classes, aligns) = match count {
    1 => (["hide-tail"], [align])
    2 => (["halfarrow-left", "halfarrow-right"], ["xMinYMin", "xMaxYMin"])
    _ =>
      (
        ["brace-left", "brace-center", "brace-right"],
        ["xMinYMin", "xMidYMin", "xMaxYMin"],
      )
  }
  let children : Array[HtmlNode] = []
  for i = 0; i < count; i = i + 1 {
    let svg = make_svg([make_path(svg_path(paths[i]))], [
      ("width", "400em"),
      ("height", make_em(height)),
      ("viewBox", "0 0 400000 \{view_height}"),
      ("preserveAspectRatio", aligns[i] + " slice"),
    ])
    let child = make_svg_span([classes[i]], [svg], options)
    if count > 1 {
      child.set_style("height", make_em(height))
    }
    children.push(child)
  }
  let span = if count == 1 {
    children[0]
  } else {
    make_span(["katex-stretchy"], children, options~)
  }
  span.height = height
  span.set_style("height", make_em(height))
  if min_width > 0.0 {
    span.set_style("minWidth", make_em(min_width))
  }
  span
}
