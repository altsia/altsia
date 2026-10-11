///|
fn extra_character_box(node : @katex.ParseNode) -> Bool {
  match node {
    OrdGroup(body=[only], ..) | Color(body=[only], ..) =>
      extra_character_box(only)
    Font(body~, ..) => extra_character_box(body)
    MathOrd(..) | TextOrd(..) | Atom(..) => true
    _ => false
  }
}

///|
fn extra_cancel_line(descending : Bool) -> HtmlNode {
  let line = html_node("line")
  line.set_attribute("x1", "0")
  line.set_attribute("y1", if descending { "0" } else { "100%" })
  line.set_attribute("x2", "100%")
  line.set_attribute("y2", if descending { "100%" } else { "0" })
  line.set_attribute("stroke-width", "0.046em")
  line
}

///|
fn extra_stretchy_enclose(
  inner : HtmlNode,
  label : String,
  top_pad : Double,
  bottom_pad : Double,
  options : Options,
) -> HtmlNode {
  let height = inner.height + inner.depth + top_pad + bottom_pad
  let result = if label == "fbox" || label.contains("color") || label == "angl" {
    let box = make_span(["katex-stretchy", label], [], options~)
    if label == "fbox" && options.color is Some(_) {
      if options.get_color() is Some(color) {
        box.set_style("borderColor", color)
      }
    }
    box
  } else {
    let lines : Array[HtmlNode] = []
    if label == "bcancel" || label == "xcancel" {
      lines.push(extra_cancel_line(true))
    }
    if label == "cancel" || label == "xcancel" {
      lines.push(extra_cancel_line(false))
    }
    make_span(
      [],
      [make_svg(lines, [("width", "100%"), ("height", make_em(height))])],
      options~,
    )
  }
  result.height = height
  result.set_style("height", make_em(height))
  result
}

///|
fn extra_enclose(
  command : String,
  body : @katex.ParseNode,
  background : String?,
  border : String?,
  options : Options,
) -> HtmlNode {
  let inner = extra_wrap_fragment(build_group(body, options), options)
  let label = command.unsafe_substring(start=1, end=command.length())
  let single_char = extra_character_box(body)
  let (image, image_shift) = if label == "sout" {
    let image = make_span(["katex-stretchy", "katex-sout"], [])
    image.height = options.metric("defaultRuleThickness") /
      options.size_multiplier
    (image, -0.5 * options.metric("xHeight"))
  } else if label == "phase" {
    let line_weight = calculate_size({ number: 0.6, unit: "pt", }, options)
    let clearance = calculate_size({ number: 0.35, unit: "ex", }, options)
    let scale = options.size_multiplier / options.base_sizing().size_multiplier
    let angle_height = inner.height + inner.depth + line_weight + clearance
    inner.set_style("paddingLeft", make_em(angle_height / 2.0 + line_weight))
    let view_height = (1000.0 * angle_height * scale).floor()
    let svg = make_svg([make_path(phase_path(view_height))], [
      ("width", "400em"),
      ("height", make_em(view_height / 1000.0)),
      ("viewBox", "0 0 400000 \{view_height}"),
      ("preserveAspectRatio", "xMinYMin slice"),
    ])
    let image = make_span(["hide-tail"], [svg], options~)
    image.set_style("height", make_em(angle_height))
    (image, inner.depth + line_weight + clearance)
  } else {
    if label.contains("cancel") {
      if !single_char {
        inner.classes.push("cancel-pad")
      }
    } else if label == "angl" {
      inner.classes.push("anglpad")
    } else {
      inner.classes.push("boxpad")
    }
    let (top_pad, bottom_pad, rule_thickness) = if label.contains("box") {
      let rule = options.metric("fboxrule").max(options.min_rule_thickness)
      let pad = options.metric("fboxsep") +
        (if label == "colorbox" { 0.0 } else { rule })
      (pad, pad, rule)
    } else if label == "angl" {
      let rule = options
        .metric("defaultRuleThickness")
        .max(options.min_rule_thickness)
      (4.0 * rule, (0.25 - inner.depth).max(0.0), rule)
    } else {
      let pad = if single_char { 0.2 } else { 0.0 }
      (pad, pad, 0.0)
    }
    let image = extra_stretchy_enclose(
      inner, label, top_pad, bottom_pad, options,
    )
    if label == "fbox" || label == "boxed" || label == "fcolorbox" {
      image.set_style("borderStyle", "solid")
      image.set_style("borderWidth", make_em(rule_thickness))
    } else if label == "angl" && rule_thickness != 0.049 {
      image.set_style("borderTopWidth", make_em(rule_thickness))
      image.set_style("borderRightWidth", make_em(rule_thickness))
    }
    if background is Some(background) {
      image.set_style("backgroundColor", background)
      if border is Some(border) {
        image.set_style("borderColor", border)
      }
    }
    (image, inner.depth + bottom_pad)
  }
  let children = if background is Some(_) {
    [vlist_elem(image, shift=image_shift), vlist_elem(inner, shift=0.0)]
  } else {
    let classes = if label.contains("cancel") || label == "phase" {
      ["svg-align"]
    } else {
      []
    }
    [
      vlist_elem(inner, shift=0.0),
      vlist_elem(image, shift=image_shift, wrapper_classes=classes),
    ]
  }
  let vlist = make_vlist("individualShift", 0.0, children, options)
  if label.contains("cancel") {
    vlist.height = inner.height
    vlist.depth = inner.depth
  }
  let classes = if label.contains("cancel") && !single_char {
    ["mord", "cancel-lap"]
  } else {
    ["mord"]
  }
  make_span(classes, [vlist], options~)
}
