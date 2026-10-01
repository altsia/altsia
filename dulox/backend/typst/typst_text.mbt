///|
fn render_text(
  body : Array[@katex.ParseNode],
  font : String,
  state : RenderState,
) -> String {
  let base = match plain_text_of(body) {
    Some(text) => quote_string(text)
    None => "(\{body.map(node => render_text_child(node, state)).join(" ")})"
  }
  match font {
    "\\textbf" => "#strong[$text\{base}$]"
    "\\textit" | "\\emph" => "#emph[$text\{base}$]"
    _ => "text\{base}"
  }
}

///|
fn render_text_child(node : @katex.ParseNode, state : RenderState) -> String {
  match node {
    TextOrd(text~, ..) | MathOrd(text~, ..) | Spacing(text~, ..) =>
      quote_string(@backend.resolve_symbol(text))
    _ => render_node(node, state)
  }
}

///|
let font_functions : Map[String, String] = Map::from_array([
  ("mathrm", "upright"),
  ("mathit", "italic"),
  ("mathbf", "bold"),
  ("mathbb", "bb"),
  ("mathcal", "cal"),
  ("mathfrak", "frak"),
  ("mathscr", "scr"),
  ("mathsf", "sans"),
  ("mathtt", "mono"),
])

///|
fn render_font(
  font : String,
  body : @katex.ParseNode,
  state : RenderState,
) -> String {
  // A purely textual body whose text is a predefined Typst operator name
  // (`\rm mod` -> `mod`) emits the bare name: it is already upright and
  // carries operator semantics.
  match body {
    OrdGroup(body=nodes, ..) if plain_text_of(nodes) is Some(text) &&
      typst_operator_names.contains(text) => text
    _ => render_font_wrapped(font, body, state)
  }
}

///|
fn render_font_wrapped(
  font : String,
  body : @katex.ParseNode,
  state : RenderState,
) -> String {
  match font_functions.get(font) {
    Some(name) => "\{name}(\{font_body(body, state)})"
    None if font == "mathsfit" => "italic(sans(\{font_body(body, state)}))"
    // mathnormal, bold (for \pmb bodies handled elsewhere): pass through
    _ => render_node(body, state)
  }
}

///|
/// Renders a font body: purely textual bodies collapse to a quoted string so
/// the letters render as one word (`upright("abc")`), not as space-separated
/// atoms; anything with math structure renders recursively.
fn font_body(body : @katex.ParseNode, state : RenderState) -> String {
  match body {
    OrdGroup(body=nodes, ..) =>
      match plain_text_of(nodes) {
        Some(text) => quote_string(text)
        None => wrap_arg(render_nodes(nodes, state))
      }
    _ => wrap_arg(render_node(body, state))
  }
}
