///|
/// `\text{...}` and friends. The font field holds the command itself
/// (`\text`, `\textbf`, `\textrm`, ...), and the body is text-mode content.
fn render_text(body : Array[@katex.ParseNode], font : String) -> String {
  "\{font}{\{join_tight(body.map(node => render_node(node)))}}"
}

///|
/// `\mathbb{...}` and friends. The font field holds the canonical font name;
/// the command is looked up from it. `mathsfit` has no public KaTeX command
/// and is approximated by `\mathsf` (documented approximation).
fn render_font(font : String, body : @katex.ParseNode) -> String {
  let command = match font {
    "mathrm" => "\\mathrm"
    "mathit" => "\\mathit"
    "mathbf" => "\\mathbf"
    "mathnormal" => "\\mathnormal"
    "mathbb" => "\\mathbb"
    "mathcal" => "\\mathcal"
    "mathfrak" => "\\mathfrak"
    "mathscr" => "\\mathscr"
    "mathsf" => "\\mathsf"
    "mathtt" => "\\mathtt"
    "boldsymbol" => "\\boldsymbol"
    "mathsfit" => "\\mathsf"
    _ => "\\mathrm"
  }
  "\{command}{\{font_body(body)}}"
}

///|
fn font_body(body : @katex.ParseNode) -> String {
  match body {
    @katex.ParseNode::OrdGroup(body=nodes, ..) =>
      join_tight(nodes.map(render_node))
    _ => render_node(body)
  }
}
