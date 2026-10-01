///|
fn render_left_right(
  body : Array[@katex.ParseNode],
  left : String,
  right : String,
) -> String {
  let left = render_delimiter(left)
  let content = render_nodes(body)
  let sep = if needs_space(left, content) { " " } else { "" }
  "\\left\{left}\{sep}\{content}\\right\{render_delimiter(right)}"
}

///|
/// Emits a delimiter for `\left`/`\right`/`\middle` position. The parser keeps
/// the original spelling (`(`, `\{`, `\Vert`, `.` for the null delimiter), so
/// it is re-emitted verbatim.
fn render_delimiter(delim : String) -> String {
  guard !@backend.is_null_delimiter(delim) else { "." }
  delim
}

///|
/// `\big`/`\Big`/`\bigg`/`\Bigg` carry sizes 1..4; the math class selects the
/// `l`/`r`/`m` suffix (plain for `Mord`).
fn render_delim_sizing(
  size : Int,
  mclass : @katex.AtomFamily,
  delim : String,
) -> String {
  let base = match size {
    2 => "\\Big"
    3 => "\\bigg"
    4 => "\\Bigg"
    _ => "\\big"
  }
  let suffix = match mclass {
    @katex.AtomFamily::Mopen => "l"
    @katex.AtomFamily::Mclose => "r"
    @katex.AtomFamily::Mbin | @katex.AtomFamily::Mrel => "m"
    _ => ""
  }
  "\{base}\{suffix}\{delim}"
}

///|
fn render_kern(dimension : @katex.Measurement) -> String {
  let command = if dimension.unit == "mu" { "\\mkern" } else { "\\kern" }
  "\{command}{\{render_measurement(dimension)}}"
}
