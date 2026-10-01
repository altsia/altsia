///|
/// KaTeX accent command -> Typst accent function name. Function form is
/// emitted (`hat(x)`); Typst auto-stretches the accent to the base width, so
/// `\widehat`/`\widetilde`/`\overrightarrow` all map onto the same functions.
let accent_names : Map[String, String] = Map::from_array([
  ("\\grave", "grave"),
  ("\\acute", "acute"),
  ("\\ddot", "dot.double"),
  ("\\tilde", "tilde"),
  ("\\bar", "macron"),
  ("\\breve", "breve"),
  ("\\check", "caron"),
  ("\\hat", "hat"),
  ("\\vec", "arrow"),
  ("\\dot", "dot"),
  ("\\mathring", "circle"),
  ("\\widecheck", "caron"),
  ("\\widehat", "hat"),
  ("\\widetilde", "tilde"),
  ("\\overrightarrow", "arrow"),
  ("\\overleftarrow", "arrow.l"),
  ("\\Overrightarrow", "arrow"),
  ("\\overleftrightarrow", "arrow.l.r"),
  ("\\overgroup", "overparen"),
  ("\\overlinesegment", "overline"),
  ("\\overleftharpoon", "harpoon.lt"),
  ("\\overrightharpoon", "harpoon"),
  ("\\'", "acute"),
  ("\\`", "grave"),
  ("\\^", "hat"),
  ("\\~", "tilde"),
  ("\\=", "macron"),
  ("\\u", "breve"),
  ("\\.", "dot"),
  ("\\\"", "dot.double"),
  ("\\r", "circle"),
  ("\\H", "acute.double"),
  ("\\v", "caron"),
])

///|
fn render_accent(
  label : String,
  base : @katex.ParseNode,
  state : RenderState,
) -> String {
  guard label != "\\textcircled" else {
    return "#circle[$\{render_node(base, state)}$]"
  }
  accent_names
  .get(label)
  .map_or(unsupported_comment("accent \{label}"), name => {
    math_fn(name, render_node(base, state))
  })
}

///|
/// Detects the `\dddot`/`\ddddot` macro expansion shape
/// `\overset{\raisebox{-0.1ex}{\normalsize ...}}{x}` and returns the number of
/// dots (3 or 4) in the raise box, or `None`.
fn dddot_dots(node : @katex.ParseNode) -> Int? {
  match node {
    OrdGroup(
      body=[
        RaiseBox(
          body=Styling(body=[OrdGroup(body=[Sizing(body=dots, ..)], ..)], ..),
          ..
        ),
        ..,
      ],
      ..
    ) if dots.length() >= 3 &&
      dots.length() <= 4 &&
      dots.all(n => n is TextOrd(text=".", ..)) => Some(dots.length())
    _ => None
  }
}

///|
fn dddot_symbol(count : Int) -> String {
  match count {
    4 => "dot.quad"
    _ => "dot.triple"
  }
}

///|
fn render_horiz_brace(
  label : String,
  base : @katex.ParseNode,
  state : RenderState,
) -> String {
  math_fn(horiz_brace_name(label), render_node(base, state))
}

///|
fn horiz_brace_name(label : String) -> String {
  match label {
    "\\overbracket" => "overbracket"
    "\\underbrace" => "underbrace"
    "\\underbracket" => "underbracket"
    _ => "overbrace"
  }
}

///|
fn render_xarrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
  state : RenderState,
) -> String {
  let arrow = xarrow_name(label)
  let body_str = wrap_arg(render_node(body, state))
  let b_str = below.map_or("", node => {
    ", b: \{wrap_arg(render_node(node, state))}"
  })
  // The `body` field holds the label drawn above the arrow.
  "attach(\{arrow}, t: \{body_str}\{b_str})"
}

///|
/// Typst symbol name for the arrow of each `\x...` command. In the AST the
/// `body` field holds the label drawn above the arrow.
let xarrow_names : Map[String, String] = Map::from_array([
  ("\\xrightarrow", "arrow.r"),
  ("\\xleftarrow", "arrow.l"),
  ("\\xLeftarrow", "arrow.l.double"),
  ("\\xRightarrow", "arrow.r.double"),
  ("\\xleftrightarrow", "arrow.l.r"),
  ("\\xLeftrightarrow", "arrow.l.r.double"),
  ("\\xhookleftarrow", "arrow.l.hook"),
  ("\\xhookrightarrow", "arrow.r.hook"),
  ("\\xmapsto", "arrow.r.bar"),
  ("\\xrightharpoondown", "harpoon.rb"),
  ("\\xrightharpoonup", "harpoon.rt"),
  ("\\xleftharpoondown", "harpoon.lb"),
  ("\\xleftharpoonup", "harpoon.lt"),
  ("\\xrightleftharpoons", "harpoons.rtlb"),
  ("\\xleftrightharpoons", "harpoons.ltrb"),
  ("\\xlongequal", "stretch(=)"),
  ("\\xtwoheadrightarrow", "arrow.r.twohead"),
  ("\\xtwoheadleftarrow", "arrow.l.twohead"),
  ("\\xtofrom", "arrow.l.r"),
  ("\\xrightleftarrows", "arrows.rl"),
])

///|
fn xarrow_name(label : String) -> String {
  xarrow_names.get(label).unwrap_or("arrow.r")
}
