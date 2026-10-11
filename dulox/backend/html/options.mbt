///|
priv struct Options {
  style : Int
  size : Int
  text_size : Int
  size_multiplier : Double
  font : String
  font_family : String
  font_weight : String
  font_shape : String
  color : String?
  phantom : Bool
  max_size : Double
  min_rule_thickness : Double
}

///|
fn Options::make(
  display_mode? : Bool = false,
  max_size? : Double = 1.0 / 0.0,
  min_rule_thickness? : Double = 0.0,
) -> Options {
  {
    style: if display_mode {
      0
    } else {
      2
    },
    size: 6,
    text_size: 6,
    size_multiplier: 1.0,
    font: "",
    font_family: "",
    font_weight: "",
    font_shape: "",
    color: None,
    phantom: false,
    max_size,
    min_rule_thickness,
  }
}

///|
let size_multipliers : Array[Double] = [
  0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.2, 1.44, 1.728, 2.074, 2.488,
]

///|
let size_style_map : Array[Array[Int]] = [
  [1, 1, 1],
  [2, 1, 1],
  [3, 1, 1],
  [4, 2, 1],
  [5, 2, 1],
  [6, 3, 1],
  [7, 4, 2],
  [8, 6, 3],
  [9, 7, 6],
  [10, 8, 7],
  [11, 10, 9],
]

///|
fn size_at_style(size : Int, style : Int) -> Int {
  if style < 4 {
    size
  } else {
    size_style_map[size - 1][style / 2 - 1]
  }
}

///|
fn Options::with_style(self : Options, style : Int) -> Options {
  if self.style == style {
    self
  } else {
    let size = size_at_style(self.text_size, style)
    { ..self, style, size, size_multiplier: size_multipliers[size - 1], }
  }
}

///|
fn Options::with_size(self : Options, size : Int) -> Options {
  if self.size == size && self.text_size == size {
    self
  } else {
    {
      ..self,
      style: style_text(self.style),
      size,
      text_size: size,
      size_multiplier: size_multipliers[size - 1],
    }
  }
}

///|
fn Options::base_style(self : Options, style : Int) -> Options {
  let size = size_at_style(6, style)
  { ..self, style, size, size_multiplier: size_multipliers[size - 1], }
}

///|
fn Options::base_sizing(self : Options) -> Options {
  let size = if self.style >= 6 { 1 } else if self.style >= 4 { 3 } else { 6 }
  {
    ..self,
    style: style_text(self.style),
    size,
    size_multiplier: size_multipliers[size - 1],
  }
}

///|
fn Options::sizing_classes(self : Options, old : Options) -> Array[String] {
  if self.size == old.size {
    []
  } else {
    [
      "katex-sizing",
      "reset-size" + old.size.to_string(),
      "size" + self.size.to_string(),
    ]
  }
}

///|
fn Options::base_sizing_classes(self : Options) -> Array[String] {
  if self.size == 6 {
    []
  } else {
    ["katex-sizing", "reset-size" + self.size.to_string(), "size6"]
  }
}

///|
fn Options::get_color(self : Options) -> String? {
  if self.phantom {
    Some("transparent")
  } else {
    self.color
  }
}

///|
fn style_sup(style : Int) -> Int {
  [4, 5, 4, 5, 6, 7, 6, 7][style]
}

///|
fn style_sub(style : Int) -> Int {
  [5, 5, 5, 5, 7, 7, 7, 7][style]
}

///|
fn style_frac_num(style : Int) -> Int {
  [2, 3, 4, 5, 6, 7, 6, 7][style]
}

///|
fn style_frac_den(style : Int) -> Int {
  [3, 3, 5, 5, 7, 7, 7, 7][style]
}

///|
fn style_cramp(style : Int) -> Int {
  [1, 1, 3, 3, 5, 5, 7, 7][style]
}

///|
fn style_text(style : Int) -> Int {
  [0, 1, 2, 3, 2, 3, 2, 3][style]
}
