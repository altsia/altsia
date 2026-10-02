///|
fn render_lap(
  alignment : @katex.LapAlignment,
  body : @katex.ParseNode,
  state : RenderState,
) -> MathMlNode {
  let attrs = match alignment {
    LLap => [("lspace", "-1width"), ("width", "0px")]
    CLap => [("lspace", "-0.5width"), ("width", "0px")]
    RLap => [("width", "0px")]
  }
  element("mpadded", children=[render_group(body, state)], attributes=attrs)
}

///|
fn render_rule(
  width : @katex.Measurement,
  height : @katex.Measurement,
  shift : @katex.Measurement?,
  state : RenderState,
) -> MathMlNode {
  let background = state.color.unwrap_or("black")
  let rule = element("mspace", attributes=[
    ("mathbackground", background),
    ("width", measurement(width)),
    ("height", measurement(height)),
  ])
  let attrs = shift.map_or([], value => [("voffset", measurement(value))])
  element("mpadded", children=[rule], attributes=attrs)
}

///|
fn render_math_choice(
  display : Array[@katex.ParseNode],
  text : Array[@katex.ParseNode],
  script : Array[@katex.ParseNode],
  scriptscript : Array[@katex.ParseNode],
  state : RenderState,
) -> MathMlNode {
  let selected = @backend.math_choice_variant(
    display,
    text,
    script,
    scriptscript,
    state.style,
  )
  make_row(render_expression(selected, state))
}

///|
fn render_xarrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
  state : RenderState,
) -> MathMlNode {
  let arrow = stretchy(label).with_attribute(
    "minsize",
    if label.has_prefix("\\x") {
      "1.75em"
    } else {
      "3em"
    },
  )
  match below {
    Some(lower) =>
      element("munderover", children=[
        arrow,
        element("mpadded", children=[render_group(lower, state)], attributes=[
          ("width", "+0.6em"),
          ("lspace", "0.3em"),
        ]),
        element("mpadded", children=[render_group(body, state)], attributes=[
          ("width", "+0.6em"),
          ("lspace", "0.3em"),
        ]),
      ])
    None =>
      element("mover", children=[
        arrow,
        element("mpadded", children=[render_group(body, state)], attributes=[
          ("width", "+0.6em"),
          ("lspace", "0.3em"),
        ]),
      ])
  }
}

///|
fn render_sup_sub(
  base : @katex.ParseNode?,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  state : RenderState,
) -> MathMlNode {
  let limits = operator_uses_limits(base, state)
  let base = base.map_or(element("mrow"), value => render_group(value, state))
  let script_style = match state.style {
    DisplayStyle | TextStyle => @katex.StyleLevel::ScriptStyle
    ScriptStyle | ScriptScriptStyle => @katex.StyleLevel::ScriptScriptStyle
  }
  let script_state = { ..state, style: script_style, }
  match (sub, sup) {
    (Some(lower), Some(upper)) =>
      element(if limits { "munderover" } else { "msubsup" }, children=[
        base,
        render_group(lower, script_state),
        render_group(upper, script_state),
      ])
    (Some(lower), None) =>
      element(if limits { "munder" } else { "msub" }, children=[
        base,
        render_group(lower, script_state),
      ])
    (None, Some(upper)) =>
      element(if limits { "mover" } else { "msup" }, children=[
        base,
        render_group(upper, script_state),
      ])
    (None, None) => base
  }
}

///|
fn operator_uses_limits(base : @katex.ParseNode?, state : RenderState) -> Bool {
  guard base is Some(base) else { return false }
  match base {
    Op(limits=true, always_handle_sup_sub~, ..)
    | OperatorName(limits=true, always_handle_sup_sub~, ..) =>
      state.style is DisplayStyle || always_handle_sup_sub
    _ => false
  }
}
