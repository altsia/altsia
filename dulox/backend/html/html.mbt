///|
pub fn render(
  nodes : Array[@katex.ParseNode],
  config? : RenderConfig = Default::default(),
) -> String {
  let options = Options::make(
    display_mode=config.display_mode,
    max_size=config.max_size,
    min_rule_thickness=config.min_rule_thickness,
  )
  let (body, options) = match nodes {
    [Styling(style=DisplayStyle, reset_font=true, body~, ..)] =>
      (body, options.with_style(0))
    _ => (nodes, options)
  }
  let rendered = make_span(["katex"], [build_html(body, options)])
  if config.display_mode {
    let classes = ["katex-display"]
    if config.leqno {
      classes.push("leqno")
    }
    if config.fleqn {
      classes.push("fleqn")
    }
    make_span(classes, [rendered]).to_markup()
  } else {
    rendered.to_markup()
  }
}

///|
fn build_unbreakable(children : Array[HtmlNode], options : Options) -> HtmlNode {
  let body = make_span(["katex-base"], children, options~)
  let strut = make_span(["katex-strut"], [])
  strut.set_style("height", make_em(body.height + body.depth))
  if body.depth != 0.0 {
    strut.set_style("vertical-align", make_em(-body.depth))
  }
  body.children.insert(0, strut)
  body
}

///|
fn build_html(nodes : Array[@katex.ParseNode], options : Options) -> HtmlNode {
  let (nodes, tag) : (Array[@katex.ParseNode], Array[@katex.ParseNode]?) = match
    nodes {
    [Tag(body~, tag~, ..)] => (body, Some(tag))
    _ => (nodes, None)
  }
  let expression = build_expression(nodes, options, root=true)
  let equation_number = if expression.length() == 2 &&
    expression[1].has_class("katex-tag") {
    expression.pop()
  } else {
    None
  }
  let children : Array[HtmlNode] = []
  let mut parts : Array[HtmlNode] = []
  let mut i = 0
  while i < expression.length() {
    let node = expression[i]
    parts.push(node)
    if node.has_class("mbin") ||
      node.has_class("mrel") ||
      node.has_class("allowbreak") {
      let mut prevent_break = false
      while i + 1 < expression.length() &&
            expression[i + 1].has_class("mspace") &&
            !expression[i + 1].has_class("katex-newline") {
        i += 1
        parts.push(expression[i])
        if expression[i].has_class("nobreak") {
          prevent_break = true
        }
      }
      if !prevent_break {
        children.push(build_unbreakable(parts, options))
        parts = []
      }
    } else if node.has_class("katex-newline") {
      ignore(parts.pop())
      if !parts.is_empty() {
        children.push(build_unbreakable(parts, options))
        parts = []
      }
      children.push(node)
    }
    i += 1
  }
  if !parts.is_empty() {
    children.push(build_unbreakable(parts, options))
  }
  let tag_child = tag.map(tag => {
    let child = build_unbreakable(build_expression(tag, options), options)
    child.classes = ["katex-tag"]
    children.push(child)
    child
  })
  if tag_child is None {
    if equation_number is Some(number) {
      children.push(number)
    }
  }
  let html = make_span(["katex-html"], children)
  html.set_attribute("aria-hidden", "true")
  if tag_child is Some(child) {
    let strut = child.children[0]
    strut.set_style("height", make_em(html.height + html.depth))
    if html.depth != 0.0 {
      strut.set_style("vertical-align", make_em(-html.depth))
    }
  }
  html
}

///|
fn build_group(
  node : @katex.ParseNode,
  options : Options,
  base_options? : Options,
) -> HtmlNode {
  let group = build_node(node, options)
  guard base_options is Some(base) && options.size != base.size else { group }
  let sized = make_span(options.sizing_classes(base), [group], options~)
  let multiplier = options.size_multiplier / base.size_multiplier
  sized.height *= multiplier
  sized.depth *= multiplier
  sized
}

///|
fn atom_class(family : @katex.AtomFamily) -> String {
  @backend.atom_family_name(family)
}

///|
fn style_id(style : @katex.StyleLevel) -> Int {
  match style {
    DisplayStyle => 0
    TextStyle => 2
    ScriptStyle => 4
    ScriptScriptStyle => 6
  }
}

///|
fn make_null_delimiter(options : Options, classes : Array[String]) -> HtmlNode {
  make_span([..classes, "nulldelimiter", ..options.base_sizing_classes()], [])
}

///|
fn build_node(node : @katex.ParseNode, options : Options) -> HtmlNode {
  match node {
    MathOrd(..) | TextOrd(..) => make_ord(node, options)
    Atom(text~, mode~, family~, ..) =>
      make_math_symbol(text, mode, options, [atom_class(family)])
    OrdGroup(body~, semisimple~, ..) => {
      let inner = build_expression(body, options, real_group=!semisimple)
      if semisimple {
        make_fragment(inner)
      } else {
        make_span(["mord"], inner, options~)
      }
    }
    Color(body~, color~, ..) =>
      make_fragment(
        build_expression(
          body,
          { ..options, color: Some(color), },
          real_group=false,
        ),
      )
    Sizing(body~, size~, ..) =>
      sizing_group(body, options.with_size(size), options)
    Styling(body~, style~, reset_font~, ..) => {
      let styled = options.with_style(style_id(style))
      sizing_group(
        body,
        if reset_font {
          { ..styled, font: "", }
        } else {
          styled
        },
        options,
      )
    }
    Font(body~, font~, ..) => build_group(body, { ..options, font, })
    Text(body~, font~, ..) => {
      let new_options = text_options(font, options)
      make_span(
        ["mord", "text"],
        build_expression(body, new_options),
        options=new_options,
      )
    }
    MClass(body~, mclass~, ..) =>
      make_span([atom_class(mclass)], build_expression(body, options), options~)
    HtmlMathML(html~, ..) =>
      make_fragment(build_expression(html, options, real_group=false))
    MathChoice(display~, text~, script~, scriptscript~, ..) => {
      let body = match options.style / 2 {
        0 => display
        1 => text
        2 => script
        _ => scriptscript
      }
      make_fragment(build_expression(body, options, real_group=false))
    }
    Kern(dimension~, ..) => make_glue(dimension, options)
    Spacing(text~, mode~, ..) => render_spacing_node(node, text, mode, options)
    Href(href~, body~, ..) => {
      let span = make_span(
        [],
        build_expression(body, options, real_group=false),
        options~,
      )
      let anchor = { ..span, kind: "a", }
      anchor.set_attribute("href", href)
      anchor
    }
    Html(attributes~, body~, ..) => {
      let classes = ["enclosing"]
      if attributes.get("class") is Some(value) {
        let mut word = ""
        for ch in value.to_array() {
          if ch.is_whitespace() {
            if word != "" {
              classes.push(word)
              word = ""
            }
          } else {
            word += ch.to_string()
          }
        }
        if word != "" {
          classes.push(word)
        }
      }
      let span = make_span(
        classes,
        build_expression(body, options, real_group=false),
        options~,
      )
      for key, value in attributes {
        if key != "class" {
          span.set_attribute(key, value)
        }
      }
      span
    }
    Internal(..) | EnvironmentEnd(..) => make_fragment([])
    _ => {
      guard render_layout_node(node, options) is Some(result) else {
        guard render_extra_node(node, options) is Some(result) else {
          abort("Unexpected non-renderable KaTeX parse node")
        }
        return result
      }
      result
    }
  }
}

///|
fn sizing_group(
  nodes : Array[@katex.ParseNode],
  options : Options,
  base : Options,
) -> HtmlNode {
  let inner = build_expression(nodes, options, real_group=false)
  let multiplier = options.size_multiplier / base.size_multiplier
  for node in inner {
    if node.classes.search("katex-sizing") is Some(position) {
      if node.classes[position + 1] == "reset-size\{options.size}" {
        node.classes[position + 1] = "reset-size\{base.size}"
      }
    } else {
      for class_name in options.sizing_classes(base) {
        node.classes.push(class_name)
      }
    }
    node.height *= multiplier
    node.depth *= multiplier
  }
  make_fragment(inner)
}

///|
fn text_options(font : String, options : Options) -> Options {
  match font {
    "\\textrm" | "\\textnormal" =>
      { ..options, font: "", font_family: "textrm", }
    "\\textsf" => { ..options, font: "", font_family: "textsf", }
    "\\texttt" => { ..options, font: "", font_family: "texttt", }
    "\\textbf" => { ..options, font: "", font_weight: "textbf", }
    "\\textmd" => { ..options, font: "", font_weight: "textmd", }
    "\\textit" => { ..options, font: "", font_shape: "textit", }
    "\\textup" => { ..options, font: "", font_shape: "textup", }
    "\\emph" =>
      {
        ..options,
        font: "",
        font_shape: if options.font_shape == "textit" {
          "textup"
        } else {
          "textit"
        },
      }
    _ => options
  }
}

///|
fn render_spacing_node(
  node : @katex.ParseNode,
  text : String,
  mode : @katex.Mode,
  options : Options,
) -> HtmlNode {
  match text {
    "\\nobreak" => make_span(["mspace", "nobreak"], [], options~)
    "\\allowbreak" => make_span(["mspace", "allowbreak"], [], options~)
    _ => {
      let class_name = if text == "~" || text == "\\nobreakspace" {
        "nobreak"
      } else {
        ""
      }
      if mode == @katex.Mode::Text {
        let ord = make_ord(node, options)
        ord.classes.push(class_name)
        ord
      } else {
        make_span(
          ["mspace", class_name],
          [make_math_symbol(text, mode, options, [])],
          options~,
        )
      }
    }
  }
}

///|
fn make_glue(measurement : @katex.Measurement, options : Options) -> HtmlNode {
  let span = make_span(["mspace"], [], options~)
  span.set_style("margin-right", make_em(calculate_size(measurement, options)))
  span
}
