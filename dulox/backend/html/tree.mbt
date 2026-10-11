///|
#warnings("-unused_mut")
priv struct HtmlNode {
  kind : String
  mut classes : Array[String]
  mut children : Array[HtmlNode]
  mut text : String
  mut height : Double
  mut depth : Double
  mut max_font_size : Double
  mut italic : Double
  mut skew : Double
  mut width : Double
  style : Array[(String, String)]
  attributes : Array[(String, String)]
  mut middle : (String, Options)?
}

///|
fn html_node(
  kind : String,
  classes? : Array[String] = [],
  children? : Array[HtmlNode] = [],
  text? : String = "",
) -> HtmlNode {
  {
    kind,
    classes,
    children,
    text,
    height: 0.0,
    depth: 0.0,
    max_font_size: 0.0,
    italic: 0.0,
    skew: 0.0,
    width: 0.0,
    style: [],
    attributes: [],
    middle: None,
  }
}

///|
fn set_pair(
  entries : Array[(String, String)],
  key : String,
  value : String,
) -> Unit {
  for i = 0; i < entries.length(); i = i + 1 {
    if entries[i].0 == key {
      entries[i] = (key, value)
      return
    }
  }
  entries.push((key, value))
}

///|
fn HtmlNode::set_style(self : HtmlNode, key : String, value : String) -> Unit {
  set_pair(self.style, key, value)
}

///|
fn HtmlNode::set_attribute(
  self : HtmlNode,
  key : String,
  value : String,
) -> Unit {
  set_pair(self.attributes, key, value)
}

///|
fn HtmlNode::has_class(self : HtmlNode, value : String) -> Bool {
  self.classes.contains(value)
}

///|
fn html_escape(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#x27;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn css_name(name : String) -> String {
  let out = StringBuilder()
  for ch in name {
    if ch >= 'A' && ch <= 'Z' {
      out.write_char('-')
      out.write_string(String::from_array([ch]).to_lower())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn css_string(style : Array[(String, String)]) -> String {
  let out = StringBuilder()
  for (key, value) in style {
    out.write_string(css_name(key) + ":" + value + ";")
  }
  out.to_string()
}

///|
fn class_string(classes : Array[String]) -> String {
  classes.filter(c => c != "").join(" ")
}

///|
fn invalid_attribute_name(name : String) -> Bool {
  name.any(ch => {
    ch <= '\u{0020}' ||
    ch == '"' ||
    ch == '\'' ||
    ch == '>' ||
    ch == '/' ||
    ch == '=' ||
    ch == '\u{00a0}' ||
    ch == '\u{1680}' ||
    (ch >= '\u{2000}' && ch <= '\u{200a}') ||
    ch == '\u{2028}' ||
    ch == '\u{2029}' ||
    ch == '\u{202f}' ||
    ch == '\u{205f}' ||
    ch == '\u{3000}' ||
    ch == '\u{feff}'
  })
}

///|
fn HtmlNode::to_markup(self : HtmlNode) -> String {
  let out = StringBuilder()
  if self.kind == "fragment" {
    for child in self.children {
      out.write_string(child.to_markup())
    }
    return out.to_string()
  }
  if self.kind == "path" {
    return "<path d=\"" + html_escape(self.text) + "\"/>"
  }
  if self.kind == "img" {
    let mut src = ""
    let mut alt = ""
    for (key, value) in self.attributes {
      if key == "src" {
        src = value
      }
      if key == "alt" {
        alt = value
      }
    }
    out.write_string(
      "<img src=\"" + html_escape(src) + "\" alt=\"" + html_escape(alt) + "\"",
    )
    let styles = css_string(self.style)
    if styles != "" {
      out.write_string(" style=\"" + html_escape(styles) + "\"")
    }
    out.write_string("'/>")
    return out.to_string()
  }
  if self.kind == "symbol" {
    let styles = (if self.italic > 0.0 {
        "margin-right:" + make_em(self.italic) + ";"
      } else {
        ""
      }) +
      css_string(self.style)
    if self.classes.is_empty() && styles == "" {
      return html_escape(self.text)
    }
    out.write_string("<span")
    if !self.classes.is_empty() {
      out.write_string(
        " class=\"" + html_escape(class_string(self.classes)) + "\"",
      )
    }
    if styles != "" {
      out.write_string(" style=\"" + html_escape(styles) + "\"")
    }
    out.write_string(">" + html_escape(self.text) + "</span>")
    return out.to_string()
  }
  out.write_string("<" + self.kind)
  if self.kind == "svg" {
    out.write_string(" xmlns=\"http://www.w3.org/2000/svg\"")
  }
  if !self.classes.is_empty() {
    out.write_string(
      " class=\"" + html_escape(class_string(self.classes)) + "\"",
    )
  }
  let styles = css_string(self.style)
  if styles != "" {
    out.write_string(" style=\"" + html_escape(styles) + "\"")
  }
  for (key, value) in self.attributes {
    if (self.kind == "span" || self.kind == "a") && invalid_attribute_name(key) {
      abort("Invalid attribute name '" + key + "'")
    }
    out.write_string(" " + key + "=\"" + html_escape(value) + "\"")
  }
  if self.kind == "line" {
    out.write_string("/>")
    return out.to_string()
  }
  out.write_char('>')
  for child in self.children {
    out.write_string(child.to_markup())
  }
  out.write_string("</" + self.kind + ">")
  out.to_string()
}

///|
fn size_from_children(node : HtmlNode) -> Unit {
  for child in node.children {
    node.height = node.height.max(child.height)
    node.depth = node.depth.max(child.depth)
    node.max_font_size = node.max_font_size.max(child.max_font_size)
  }
}

///|
fn make_span(
  classes : Array[String],
  children : Array[HtmlNode],
  options? : Options,
) -> HtmlNode {
  let node = html_node("span", classes~, children~)
  if options is Some(options) {
    if options.style >= 4 {
      node.classes.push("mtight")
    }
    if options.get_color() is Some(color) {
      node.set_style("color", color)
    }
  }
  size_from_children(node)
  node
}

///|
fn make_fragment(children : Array[HtmlNode]) -> HtmlNode {
  let node = html_node("fragment", children~)
  size_from_children(node)
  node
}

///|
fn make_svg(
  children : Array[HtmlNode],
  attributes : Array[(String, String)],
) -> HtmlNode {
  let node = html_node("svg", children~)
  for (key, value) in attributes {
    node.set_attribute(key, value)
  }
  node
}

///|
fn make_path(path : String) -> HtmlNode {
  html_node("path", text=path)
}

///|
fn make_svg_span(
  classes : Array[String],
  children : Array[HtmlNode],
  options : Options,
) -> HtmlNode {
  let node = make_span(classes, children, options~)
  node.height = 0.0
  node.depth = 0.0
  node.max_font_size = 0.0
  node
}
