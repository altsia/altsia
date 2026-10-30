///|
/// Terminal element renderers: one function per element with custom
/// semantics, dispatched from `term_render_element` by tag name. Elements
/// without a dedicated renderer fall back to rendering their content
/// arguments.
fn term_render_element(
  element : @document.Element,
  options : TerminalOptions,
  prev~ : Char?,
  next~ : Char?,
) -> String {
  match element.tag {
    "quote" => term_render_quote(element, options)
    "image" => term_render_image(element, options)
    "pagebreak" => "\n\n"
    "draft" => term_render_draft(options)
    _ => term_render_content(element.content, options, prev~, next~)
  }
}

///|
/// `image`: an alt-text placeholder; image content is not rendered.
fn term_render_image(
  element : @document.Element,
  options : TerminalOptions,
) -> String {
  let alt = element.named
    .get("alt")
    .map_or("", value => value.term_render(options))
  let placeholder = if alt.is_empty() { "[img]" } else { "[img: \{alt}]" }
  term_style(placeholder, ansi=options.ansi, color=@chalk.Yellow, modifier=[
    @chalk.Italic,
  ])
}

///|
/// `draft`: red-colored text, equivalent to `span(style: "color: red")[(draft)]`.
/// Takes no arguments.
fn term_render_draft(options : TerminalOptions) -> String {
  term_style("(draft)", ansi=options.ansi, color=@chalk.Red)
}

///|
/// `quote`: every line prefixed with `│`, styled white-bright italic; an
/// attribution argument becomes a tail line indented 8 spaces (no right
/// alignment in the terminal).
fn term_render_quote(
  element : @document.Element,
  options : TerminalOptions,
) -> String {
  let rendered = term_render_content(element.content, options)
  let tail = element.named
    .get("attribution")
    .map_or("", value => "\n        --- \{value.term_render(options)}")
  let joined = (rendered + tail)
    .split("\n")
    .map(line => "│ \{line}")
    .join("\n")
  term_style(joined, ansi=options.ansi, color=@chalk.WhiteBright, modifier=[
    @chalk.Italic,
  ])
}

///|
/// The terminal rendering of an argument value: text renders as its text,
/// content and nested calls contain nodes prepared before rendering.
fn @document.Value::term_render(
  self : @document.Value,
  options : TerminalOptions,
) -> String {
  match self {
    Text(s) => term_render_text(s, options)
    Integer(n) => n.to_string()
    Content(blocks) => term_render_content(blocks, options)
    Call(blocks) => term_render_content(blocks, options)
    Comment(_) => ""
  }
}
