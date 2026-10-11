///|
fn symbol_info(value : String, mode : @katex.Mode) -> (String, String)? {
  symbol_data.get((if mode == Math { "math" } else { "text" }, value))
}

///|
fn symbol_value(value : String, mode : @katex.Mode) -> String {
  symbol_info(value, mode).map_or(value, entry => entry.1)
}

///|
fn lookup_metrics(
  value : String,
  font : String,
  mode : @katex.Mode,
) -> CharacterMetrics? {
  character_metrics(symbol_value(value, mode), font, mode)
}

///|
fn make_symbol(
  value : String,
  font : String,
  mode : @katex.Mode,
  options : Options,
  classes? : Array[String] = [],
) -> HtmlNode {
  let value = symbol_value(value, mode)
  let node = html_node("symbol", classes~, text=value)
  if character_metrics(value, font, mode) is Some(metrics) {
    node.height = metrics.height
    node.depth = metrics.depth
    node.italic = if mode == Text || options.font == "mathit" {
      0.0
    } else {
      metrics.italic
    }
    node.skew = metrics.skew
    node.width = metrics.width
  }
  if !value.is_empty() {
    if unicode_script(value[0].to_int()) is Some(script) {
      node.classes.push(script + "_fallback")
    }
  }
  node.text = match value {
    "î" => "ı̂"
    "ï" => "ı̈"
    "í" => "ı́"
    "ì" => "ı̀"
    _ => value
  }
  node.max_font_size = options.size_multiplier
  if options.style >= 4 {
    node.classes.push("mtight")
  }
  if options.get_color() is Some(color) {
    node.set_style("color", color)
  }
  node
}

///|
fn make_math_symbol(
  value : String,
  mode : @katex.Mode,
  options : Options,
  classes : Array[String],
) -> HtmlNode {
  if options.font == "boldsymbol" &&
    lookup_metrics(value, "Main-Bold", mode) is Some(_) {
    make_symbol(value, "Main-Bold", mode, options, classes=classes + ["mathbf"])
  } else if value == "\\" ||
    symbol_info(value, mode).map_or(true, info => info.0 == "main") {
    make_symbol(value, "Main-Regular", mode, options, classes~)
  } else {
    make_symbol(
      value,
      "AMS-Regular",
      mode,
      options,
      classes=classes + ["amsrm"],
    )
  }
}

///|
fn text_font_name(family : String, weight : String, shape : String) -> String {
  let base = match family {
    "amsrm" => "AMS"
    "textrm" | "" => "Main"
    "textsf" => "SansSerif"
    "texttt" => "Typewriter"
    _ => family
  }
  base +
  "-" +
  (if weight == "textbf" && shape == "textit" {
    "BoldItalic"
  } else if weight == "textbf" {
    "Bold"
  } else if shape == "textit" {
    "Italic"
  } else {
    "Regular"
  })
}

///|
fn math_font_name(font : String) -> String {
  match font {
    "mathbf" => "Main-Bold"
    "mathrm" => "Main-Regular"
    "textit" | "mathit" => "Main-Italic"
    "mathnormal" => "Math-Italic"
    "mathsfit" => "SansSerif-Italic"
    "mathbb" => "AMS-Regular"
    "mathcal" => "Caligraphic-Regular"
    "mathfrak" => "Fraktur-Regular"
    "mathscr" => "Script-Regular"
    "mathsf" => "SansSerif-Regular"
    "mathtt" => "Typewriter-Regular"
    _ => "Main-Regular"
  }
}

///|
fn wide_font(text : String, mode : @katex.Mode) -> (String, String)? {
  guard text.length() >= 2 && text[0] == 0xd835 else { None }
  let code = (text[0].to_int() - 0xd800) * 0x400 +
    text[1].to_int() -
    0xdc00 +
    0x10000
  let index = if code >= 0x1d400 && code < 0x1d6a4 {
    (code - 0x1d400) / 52
  } else if code >= 0x1d7ce && code <= 0x1d7ff {
    [0, -1, 8, 9, 12][(code - 0x1d7ce) / 10]
  } else if code == 0x1d6a5 || code == 0x1d6a6 {
    0
  } else {
    -1
  }
  let data = match index {
    0 => ("Main-Bold", "mathbf", "textbf")
    1 => ("Math-Italic", "mathnormal", "textit")
    2 => ("Main-BoldItalic", "boldsymbol", "boldsymbol")
    3 if code < 0x1d4b6 => ("Script-Regular", "mathscr", "textscr")
    5 => ("Fraktur-Regular", "mathfrak", "textfrak")
    6 => ("AMS-Regular", "mathbb", "textbb")
    7 => ("Fraktur-Regular", "mathboldfrak", "textboldfrak")
    8 => ("SansSerif-Regular", "mathsf", "textsf")
    9 => ("SansSerif-Bold", "mathboldsf", "textboldsf")
    10 => ("SansSerif-Italic", "mathitsf", "textitsf")
    12 => ("Typewriter-Regular", "mathtt", "texttt")
    _ => return None
  }
  Some((data.0, if mode == Math { data.1 } else { data.2 }))
}

///|
fn make_ord(group : @katex.ParseNode, options : Options) -> HtmlNode {
  let (mode, text, mathord) = match group {
    MathOrd(mode~, text~, ..) => (mode, text, true)
    TextOrd(mode~, text~, ..) | Spacing(mode~, text~, ..) => (mode, text, false)
    _ => return make_span([], [])
  }
  if wide_font(text, mode) is Some((font, font_class)) {
    return make_symbol(text, font, mode, options, classes=["mord", font_class])
  }
  let use_font = mode == Math || (mode == Text && options.font != "")
  let font_or_family = if use_font { options.font } else { options.font_family }
  if font_or_family != "" {
    let (font_name, font_classes) = if font_or_family == "boldsymbol" {
      if mathord && lookup_metrics(text, "Math-BoldItalic", mode) is Some(_) {
        ("Math-BoldItalic", ["boldsymbol"])
      } else {
        ("Main-Bold", ["mathbf"])
      }
    } else if use_font {
      (math_font_name(options.font), [options.font])
    } else {
      (
        text_font_name(
          options.font_family,
          options.font_weight,
          options.font_shape,
        ),
        [options.font_family, options.font_weight, options.font_shape],
      )
    }
    if lookup_metrics(text, font_name, mode) is Some(_) {
      return make_symbol(
        text,
        font_name,
        mode,
        options,
        classes=["mord"] + font_classes,
      )
    }
    if (text == "--" || text == "---" || text == "``" || text == "''") &&
      font_name.has_prefix("Typewriter") {
      return make_fragment(
        text
        .to_array()
        .map(ch => {
          make_symbol(
            String::from_array([ch]),
            font_name,
            mode,
            options,
            classes=["mord"] + font_classes,
          )
        }),
      )
    }
  }
  if mathord {
    make_symbol(text, "Math-Italic", mode, options, classes=[
      "mord", "mathnormal",
    ])
  } else {
    let ams = symbol_info(text, mode).map_or(false, info => info.0 == "ams")
    let classes = if ams {
      ["mord", "amsrm", options.font_weight, options.font_shape]
    } else {
      ["mord", options.font_weight, options.font_shape]
    }
    make_symbol(
      text,
      text_font_name(
        if ams {
          "amsrm"
        } else {
          "textrm"
        },
        options.font_weight,
        options.font_shape,
      ),
      mode,
      options,
      classes~,
    )
  }
}
