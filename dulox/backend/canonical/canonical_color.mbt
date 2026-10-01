///|
/// `\cancel`-family boxes and `\colorbox`/`\fcolorbox`. The label is the
/// command itself; color boxes take their color arguments first.
fn render_enclose(
  label : String,
  body : @katex.ParseNode,
  background_color : String?,
  border_color : String?,
) -> String {
  let content = render_arg(body)
  match (label, background_color, border_color) {
    ("\\colorbox", Some(background), _) =>
      "\\colorbox{\{background}}{\{content}}"
    ("\\fcolorbox", Some(background), Some(border)) =>
      "\\fcolorbox{\{border}}{\{background}}{\{content}}"
    _ => "\{label}{\{content}}"
  }
}

///|
/// `\htmlClass`/`\htmlId`/`\htmlStyle`/`\htmlData` collapse into a single
/// `Html` node with the attribute map; re-emits the corresponding command.
fn render_html(
  attributes : Map[String, String],
  body : Array[@katex.ParseNode],
) -> String {
  let content = render_nodes(body)
  if attributes.contains("class") {
    "\\htmlClass{\{attributes["class"]}}{\{content}}"
  } else if attributes.contains("id") {
    "\\htmlId{\{attributes["id"]}}{\{content}}"
  } else if attributes.contains("style") {
    "\\htmlStyle{\{attributes["style"]}}{\{content}}"
  } else if attributes.keys().length() > 0 &&
    attributes.keys().all(key => key.has_prefix("data-")) {
    let data = attributes
      .keys()
      .map(key => "\{data_key(key)}=\{attributes[key]}")
      .join(",")
    "\\htmlData{\{data}}{\{content}}"
  } else {
    content
  }
}

///|
/// `\htmlData` re-adds the `data-` prefix, so the stored attribute keys have it
/// stripped for emission.
fn data_key(key : String) -> String {
  key.strip_prefix("data-").map_or(key, StringView::to_owned)
}

///|
fn render_includegraphics(
  width : @katex.Measurement,
  height : @katex.Measurement,
  src : String,
) -> String {
  "\\includegraphics[width=\{render_measurement(width)},height=\{render_measurement(height)}]{\{src}}"
}
