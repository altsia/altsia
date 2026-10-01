///|
fn render_display_math(latex : String, options : HtmlOptions) -> Array[Node] {
  guard !options.disable_math else { [Text("$$\{latex}$$")] }

  try render_math(latex, true, target=options.target) catch {
    err => render_display_math_error(err)
  } noraise {
    content =>
      match options.target {
        Unicode => display_math_unicode(content)
        Mathml => display_math_mathml(content)
        Canonical => display_math_canonical(content)
      }
  }
}

///|
fn render_display_math_error(err : @katex.ParseFailure) -> Array[Node] {
  let message = match err {
    InvalidArgument(message~, loc~) =>
      "\{message}\{loc.map_or("", loc => ": \{loc.start}, \{loc.end}")}"
    _ => err.to_repr().to_string()
  }
  [
    el(
      "pre",
      [attr("style", css_props([("color", "red"), ("margin", "1em 0")]))],
      [Raw(message)],
    ),
  ]
}

///|
fn display_math_unicode(rendered : String) -> Array[Node] {
  [
    el(
      "pre",
      [
        attr("class", "math-display"),
        attr(
          "style",
          css_props([("margin", "1em 0"), ("text-align", "center")]),
        ),
      ],
      [Text(rendered)],
    ),
  ]
}

///|
fn display_math_mathml(rendered : String) -> Array[Node] {
  guard !rendered.is_empty() else { [] }
  [
    el(
      "span",
      [
        attr("class", "math-display"),
        attr(
          "style",
          css_props([
            ("display", "block"),
            ("margin", "1em 0"),
            ("text-align", "center"),
          ]),
        ),
      ],
      [Raw(rendered)],
    ),
  ]
}

///|
fn display_math_canonical(rendered : String) -> Array[Node] {
  guard !rendered.is_empty() else { [] }
  [Text("$$\{rendered}$$")]
}
