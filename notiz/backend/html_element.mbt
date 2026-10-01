///|
/// Element renderers: one function per element with custom semantics,
/// dispatched from `render_element` by tag name. Elements without a
/// dedicated renderer fall back to a generic `<tag>` wrapper.
fn render_element(element : ElementData, options : HtmlOptions) -> Array[Node] {
  match element.tag {
    "quote" => render_quote(element, options)
    "image" => render_image(element, options)
    "heading" => render_heading_element(element, options)
    "pagebreak" => render_pagebreak()
    "draft" => render_draft()
    _ => render_generic_element(element, options)
  }
}

///|
/// `pagebreak`: a forced page break, equivalent to
/// `div(style: "display: block; break-before: page")`.
fn render_pagebreak() -> Array[Node] {
  [
    el(
      "div",
      [
        attr(
          "style",
          css_props([("display", "block"), ("break-before", "page")]),
        ),
      ],
      [],
    ),
  ]
}

///|
/// `draft`: red-colored inline text, equivalent to
/// `span(style: "color: red")[(draft)]`. Takes no arguments.
fn render_draft() -> Array[Node] {
  [
    el("span", [attr("style", css_props([("color", "red")]))], [Text("(draft)")]),
  ]
}

///|
/// One named argument as an attribute; positional arguments are not
/// attributes.
fn named_attr(pair : (String, @parsing.Value), options : HtmlOptions) -> Attr {
  let (name, value) = pair
  attr(name, render_nodes(value.render(options)))
}

///|
/// `img`/`image`: `<img>` with the first positional argument as `src` and
/// the named `src`, `width`, `height`, `alt` arguments as attributes.
/// Children are dropped (void element); the terminal backend ignores the
/// parameters and renders children as usual.
fn render_image(element : ElementData, options : HtmlOptions) -> Array[Node] {
  let positional_src = element.positional
    .get(0)
    .map(value => render_nodes(value.render(options)))
  let named_src = element.named
    .get("src")
    .map_or([], value => [attr("src", render_nodes(value.render(options)))])
  [
    el(
      "image",
      [
        ..positional_src.map_or(named_src, src => [attr("src", src)]),
        ..["width", "height", "alt"].filter_map(name => {
          element.named
          .get(name)
          .map(value => attr(name, render_nodes(value.render(options))))
        }),
      ],
      [],
    ),
  ]
}

///|
/// `heading`: `<h{level}>` with named arguments as attributes. The `level`
/// argument is consumed (an `Integer`, or an integer `Text`); missing or
/// unparsable levels default to 1, and the level is clamped to 1..6. The
/// children render through the normal block pipeline.
fn render_heading_element(
  element : ElementData,
  options : HtmlOptions,
) -> Array[Node] {
  let level = match element.named.get("level") {
    Some(Integer(n)) => n.max(1).min(6)
    Some(Text(s)) => {
      let n = @string.parse_int(s) catch { _ => 1 }
      n.max(1).min(6)
    }
    _ => 1
  }
  let attrs = element.named
    .iter()
    .filter_map(pair => {
      let (name, _value) = pair
      guard name != "level" else { return None }
      Some(named_attr(pair, options))
    })
    .to_array()
  [el("h\{level}", attrs, join_blocks(element.children(), options))]
}

///|
/// The generic element wrapper: named arguments become attributes,
/// positional arguments are dropped, and the content arguments render
/// inline.
fn render_generic_element(
  element : ElementData,
  options : HtmlOptions,
) -> Array[Node] {
  let attrs = element.named
    .iter()
    .map(pair => named_attr(pair, options))
    .to_array()
  [
    el(
      element.tag,
      attrs,
      element.children().map(b => b.render(options)).flatten(),
    ),
  ]
}

///|
/// `quote`: `<blockquote>` with an optional right-aligned attribution
/// block (`--- author`) at the tail. The attribution is a child of the
/// blockquote, so its width is naturally bounded by it.
fn render_quote(element : ElementData, options : HtmlOptions) -> Array[Node] {
  let content = join_blocks(element.children(), options)
  let tail = element.named
    .get("attribution")
    .map_or([], value => {
      [
        Text("\n"),
        el(
          "div",
          [attr("style", css_props([("text-align", "right")]))],
          [Text("--- "), ..value.render(options)],
        ),
      ]
    })
  [el("blockquote", [], [Text("\n"), ..content, ..tail, Text("\n")])]
}

///|
/// The HTML rendering of an argument value: text values render as text,
/// a `Content` value as its block flow, and a nested `Call` recurses into
/// `render_element`.
fn @parsing.Value::render(
  self : @parsing.Value,
  options : HtmlOptions,
) -> Array[Node] {
  match self {
    Text(s) => render_text(s, options)
    Integer(n) => [Text(n.to_string())]
    Content(blocks) => join_blocks(blocks, options)
    Call(tag, positional, named) =>
      render_element({ tag, positional, named, }, options)
    Comment(s) => render_comment(s)
  }
}
