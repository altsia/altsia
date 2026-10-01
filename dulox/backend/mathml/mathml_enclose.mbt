///|
fn render_enclose(
  label : String,
  body : @katex.ParseNode,
  background : String?,
  border : String?,
  state : RenderState,
) -> MathMlNode {
  let notation = match label {
    "\\cancel" => Some("updiagonalstrike")
    "\\bcancel" => Some("downdiagonalstrike")
    "\\xcancel" => Some("updiagonalstrike downdiagonalstrike")
    "\\phase" => Some("phasorangle")
    "\\sout" => Some("horizontalstrike")
    "\\fbox" => Some("box")
    "\\angl" => Some("actuarial")
    _ => None
  }
  let attrs = [
    ..notation.map_or([], value => [("notation", value)]),
    ..background.map_or([], value => [("mathbackground", value)]),
    ..border.map_or([], value => [("style", "border: 0.04em solid \{value}")]),
  ]
  element("menclose", children=[render_group(body, state)], attributes=attrs)
}

///|
fn render_image(
  alt : String,
  width : @katex.Measurement,
  height : @katex.Measurement,
  totalheight : @katex.Measurement,
  src : String,
) -> MathMlNode {
  let attrs = [
    ("alt", alt),
    (
      "height",
      measurement(if totalheight.number > 0 { totalheight } else { height }),
    ),
    ("src", src),
    ..if width.number > 0 {
      [("width", measurement(width))]
    },
  ]
  element("mglyph", attributes=attrs)
}
