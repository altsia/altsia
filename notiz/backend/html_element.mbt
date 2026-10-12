///|
/// Element renderers: one function per element with custom semantics,
/// dispatched from `render_element` by tag name. Elements without a
/// dedicated renderer fall back to a generic `<tag>` wrapper.
fn render_element(element : ElementData, options : HtmlOptions) -> Array[Node] {
  match element.tag {
    "quote" => render_quote(element, options)
    "image" => render_image(element)
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
fn named_attr(pair : (String, @parsing.Value)) -> Attr {
  let (name, value) = pair
  attr(name, value.attribute_value())
}

///|
/// Attribute types are checked before rendering. Preserve data literally;
/// escaping belongs to Attr::render, not the document text renderer.
fn @parsing.Value::attribute_value(self : @parsing.Value) -> String {
  match self {
    Text(s) => s
    Integer(n) => n.to_string()
    _ => abort("unvalidated attribute value")
  }
}

///|
/// `image`: `<img>` with the first positional argument as `src` and
/// the named `src`, `width`, `height`, `alt` arguments as attributes.
/// Children are dropped (void element).
fn render_image(element : ElementData) -> Array[Node] {
  let positional_src = element.positional
    .get(0)
    .map(value => value.attribute_value())
  let named_src = element.named
    .get("src")
    .map_or([], value => [attr("src", value.attribute_value())])
  [
    el(
      "img",
      [
        ..positional_src.map_or(named_src, src => [attr("src", src)]),
        ..["width", "height", "alt"].filter_map(name => {
          element.named.get(name).map(value => named_attr((name, value)))
        }),
      ],
      [],
    ),
  ]
}

///|
/// The generic element wrapper: named arguments become attributes,
/// positional arguments are dropped, and the content arguments render
/// inline.
fn render_generic_element(
  element : ElementData,
  options : HtmlOptions,
) -> Array[Node] {
  let attrs = element.named.iter().map(named_attr).to_array()
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
  let content = element.children().map(block => block.render(options)).flatten()
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
/// a `Content` value as its block flow, and a nested `Call` uses the same
/// document-node conversion as a call in markup.
fn @parsing.Value::render(
  self : @parsing.Value,
  options : HtmlOptions,
) -> Array[Node] {
  match self {
    Text(s) => render_text(s, options)
    Integer(n) => [Text(n.to_string())]
    Content(blocks) => blocks.map(block => block.render(options)).flatten()
    Call(_, _, _) =>
      @parsing.flow_of(self).map(block => block.render(options)).flatten()
    Comment(s) => render_comment(s)
  }
}
