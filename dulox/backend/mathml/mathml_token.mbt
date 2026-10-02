///|
fn token(kind : String, value : String, state : RenderState) -> MathMlNode {
  let attrs = [
    ..state.math_variant.map_or([], variant => [("mathvariant", variant)]),
    ..state.color.map_or([], color => [("mathcolor", color)]),
  ]
  element(
    kind,
    children=[text_node(@backend.resolve_symbol(value))],
    attributes=attrs,
  )
}

///|
fn text_token(
  value : String,
  mode : @katex.Mode,
  state : RenderState,
) -> MathMlNode {
  let kind = match mode {
    Text => "mtext"
    Math => "mi"
  }
  let attrs = text_attributes(kind, state)
  element(
    kind,
    children=[text_node(@backend.resolve_symbol(value))],
    attributes=attrs,
  )
}

///|
fn text_ordinary(
  value : String,
  mode : @katex.Mode,
  state : RenderState,
) -> MathMlNode {
  let kind = match mode {
    Text => "mtext"
    Math =>
      if contains_ascii_digit(value) {
        "mn"
      } else if value == "\\prime" {
        "mo"
      } else {
        "mi"
      }
  }
  element(
    kind,
    children=[text_node(@backend.resolve_symbol(value))],
    attributes=text_attributes(kind, state),
  )
}

///|
fn text_attributes(
  kind : String,
  state : RenderState,
) -> Array[(String, String)] {
  let variant = if kind == "mtext" {
    text_variant(state)
  } else {
    state.math_variant
  }
  [
    ..variant.map_or([], value => [("mathvariant", value)]),
    ..state.color.map_or([], color => [("mathcolor", color)]),
  ]
}

///|
fn render_atom(
  text : String,
  family : @katex.AtomFamily,
  state : RenderState,
) -> MathMlNode {
  let attrs = [
    ..match family {
      Mpunct => [("separator", "true")]
      Mopen | Mclose => [("stretchy", "false")]
      _ => []
    },
    ..if state.math_variant is Some("bold-italic") && family is Mbin {
      [("mathvariant", "bold-italic")]
    },
  ]
  element(
    "mo",
    children=[text_node(@backend.resolve_symbol(text))],
    attributes=attrs,
  )
}

///|
fn render_spacing(value : String) -> MathMlNode {
  match value {
    " " | "\\ " | "~" | "\\space" | "\\nobreakspace" =>
      element("mtext", children=[text_node("\u{00A0}")])
    _ => element("mspace")
  }
}

///|
fn render_styling(
  body : Array[@katex.ParseNode],
  style : @katex.StyleLevel,
  reset_font : Bool,
  state : RenderState,
) -> MathMlNode {
  let child_state = if reset_font {
    { ..state, style, math_variant: None, }
  } else {
    { ..state, style, }
  }
  let (scriptlevel, displaystyle) = match style {
    DisplayStyle => ("0", "true")
    TextStyle => ("0", "false")
    ScriptStyle => ("1", "false")
    ScriptScriptStyle => ("2", "false")
  }
  element("mstyle", children=render_expression(body, child_state), attributes=[
    ("scriptlevel", scriptlevel),
    ("displaystyle", displaystyle),
  ])
}

///|
fn render_mclass(
  body : Array[@katex.ParseNode],
  mclass : @katex.AtomFamily,
  _is_character_box : Bool,
  state : RenderState,
) -> MathMlNode {
  let children = render_expression(body, state)
  match mclass {
    Minner => element("mpadded", children~)
    Mord => element("mi", children~)
    Mbin =>
      element("mo", children~, attributes=[
        ("lspace", "0.22em"),
        ("rspace", "0.22em"),
      ])
    Mpunct =>
      element("mo", children~, attributes=[
        ("lspace", "0em"),
        ("rspace", "0.17em"),
      ])
    Mopen | Mclose =>
      element("mo", children~, attributes=[("lspace", "0em"), ("rspace", "0em")])
    Mop | Mrel => element("mo", children~)
  }
}

///|
fn math_variant(font : String) -> String? {
  match font {
    "mathit" => Some("italic")
    "boldsymbol" => Some("bold-italic")
    "mathbf" => Some("bold")
    "mathbb" => Some("double-struck")
    "mathsfit" => Some("sans-serif-italic")
    "mathfrak" => Some("fraktur")
    "mathscr" | "mathcal" => Some("script")
    "mathsf" => Some("sans-serif")
    "mathtt" => Some("monospace")
    "mathrm" => Some("normal")
    _ => None
  }
}

///|
fn text_state(font : String, state : RenderState) -> RenderState {
  match font {
    "\\textrm" | "\\textnormal" => { ..state, text_family: "normal", }
    "\\textsf" => { ..state, text_family: "sans-serif", }
    "\\texttt" => { ..state, text_family: "monospace", }
    "\\textbf" => { ..state, text_bold: true, }
    "\\textmd" => { ..state, text_bold: false, }
    "\\textit" => { ..state, text_italic: true, }
    "\\textup" => { ..state, text_italic: false, }
    "\\emph" => { ..state, text_italic: !state.text_italic, }
    _ => state
  }
}

///|
fn text_variant(state : RenderState) -> String? {
  if state.text_family == "monospace" {
    Some("monospace")
  } else if state.text_family == "sans-serif" &&
    state.text_bold &&
    state.text_italic {
    Some("sans-serif-bold-italic")
  } else if state.text_family == "sans-serif" && state.text_bold {
    Some("bold-sans-serif")
  } else if state.text_family == "sans-serif" && state.text_italic {
    Some("sans-serif-italic")
  } else if state.text_family == "sans-serif" {
    Some("sans-serif")
  } else if state.text_bold && state.text_italic {
    Some("bold-italic")
  } else if state.text_bold {
    Some("bold")
  } else if state.text_italic {
    Some("italic")
  } else {
    None
  }
}
