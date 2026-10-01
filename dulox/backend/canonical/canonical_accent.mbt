///|
fn render_horiz_brace(
  label : String,
  _is_over : Bool,
  base : @katex.ParseNode,
) -> String {
  "\{label}{\{render_arg(base)}}"
}

///|
/// `\xrightarrow[label]{body}`: the required `body` is the label drawn above
/// the arrow, the optional argument draws below.
fn render_xarrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
) -> String {
  let below = below.map_or("", node => "[\{render_arg(node)}]")
  "\{label}\{below}{\{render_arg(body)}}"
}
