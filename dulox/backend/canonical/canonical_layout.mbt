///|
/// A `\genfrac`-family node. Common shapes render as their canonical command
/// (`\frac`, `\binom`, `\cfrac`); other delimiter/bar combinations fall back
/// to `\genfrac` with the reconstructed arguments.
fn render_genfrac(
  numer : String,
  denom : String,
  continued : Bool,
  has_bar_line : Bool,
  bar_size : @katex.Measurement?,
  left_delim : String?,
  right_delim : String?,
) -> String {
  match (has_bar_line, left_delim, right_delim) {
    (true, None, None) if continued => "\\cfrac{\{numer}}{\{denom}}"
    (true, None, None) => "\\frac{\{numer}}{\{denom}}"
    (false, Some(left), Some(right)) => render_no_bar(numer, denom, left, right)
    (true, left, right) =>
      "\\genfrac{\{left.unwrap_or("")}}{\{right.unwrap_or("")}}{\{bar_size.map_or("", render_measurement)}}{}{\{numer}}{\{denom}}"
    (false, left, right) =>
      "\\genfrac{\{left.unwrap_or("")}}{\{right.unwrap_or("")}}{0pt}{}{\{numer}}{\{denom}}"
  }
}

///|
fn render_no_bar(
  numer : String,
  denom : String,
  left : String,
  right : String,
) -> String {
  match (left, right) {
    ("(", ")") => "\\binom{\{numer}}{\{denom}}"
    _ => "\\genfrac{\{left}}{\{right}}{0pt}{}{\{numer}}{\{denom}}"
  }
}

///|
/// A `\genfrac` wrapped in a style node folds into the style-specific command
/// when one exists (`\dfrac`/`\tfrac`/`\cfrac`/`\dbinom`/`\tbinom`); other
/// style/genfrac combinations fall back to `\style` followed by the plain
/// genfrac rendering.
fn render_styled_genfrac(
  style : @katex.StyleLevel,
  numer : @katex.ParseNode,
  denom : @katex.ParseNode,
  continued : Bool,
  has_bar_line : Bool,
  bar_size : @katex.Measurement?,
  left_delim : String?,
  right_delim : String?,
) -> String {
  let numer = render_arg(numer)
  let denom = render_arg(denom)
  guard styled_genfrac_command(
      style, continued, has_bar_line, left_delim, right_delim,
    )
    is Some(command) else {
    let plain = render_genfrac(
      numer, denom, continued, has_bar_line, bar_size, left_delim, right_delim,
    )
    return "\{style_command(style)} \{plain}"
  }
  "\{command}{\{numer}}{\{denom}}"
}

///|
fn styled_genfrac_command(
  style : @katex.StyleLevel,
  continued : Bool,
  has_bar_line : Bool,
  left_delim : String?,
  right_delim : String?,
) -> String? {
  guard !continued else { return Some("\\cfrac") }
  match (has_bar_line, left_delim, right_delim) {
    (true, None, None) =>
      match style {
        @katex.StyleLevel::DisplayStyle => Some("\\dfrac")
        @katex.StyleLevel::TextStyle => Some("\\tfrac")
        _ => None
      }
    (false, Some("("), Some(")")) =>
      match style {
        @katex.StyleLevel::DisplayStyle => Some("\\dbinom")
        @katex.StyleLevel::TextStyle => Some("\\tbinom")
        _ => None
      }
    _ => None
  }
}
