///|
/// Terminal element renderers: one function per element with custom
/// semantics, dispatched from `term_render_element` by tag name. Elements
/// without a dedicated renderer fall back to rendering their content
/// arguments.
fn term_render_element(
  element : ElementData,
  options : TerminalOptions,
) -> String {
  match element.tag {
    "quote" => term_render_quote(element, options)
    "image" => term_render_image(element, options)
    "draft" => term_render_draft(options)
    _ => element.children().map(b => b.term_render(options)).join("")
  }
}

///|
/// `image`: an alt-text placeholder; image content is not rendered.
fn term_render_image(
  element : ElementData,
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
  element : ElementData,
  options : TerminalOptions,
) -> String {
  let rendered = element.children().map(b => b.term_render(options)).join("")
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
/// a `Content` value as its block flow, and a nested `Call` recurses into
/// `term_render_element`.
fn @parsing.Value::term_render(
  self : @parsing.Value,
  options : TerminalOptions,
) -> String {
  match self {
    Text(s) => term_render_text(s, options)
    Integer(n) => n.to_string()
    Content(blocks) => blocks.map(b => b.term_render(options)).join("")
    Call(tag, positional, named) =>
      term_render_element({ tag, positional, named, }, options)
    Comment(_) => ""
  }
}
