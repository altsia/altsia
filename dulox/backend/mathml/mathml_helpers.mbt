///|
fn stretchy(label : String) -> MathMlNode {
  let value = match label {
    "\\widehat" => "^"
    "\\widecheck" => "ˇ"
    "\\widetilde" | "\\utilde" => "~"
    "\\overleftarrow" | "\\underleftarrow" | "\\xleftarrow" | "\\cdleftarrow" =>
      "←"
    "\\overrightarrow"
    | "\\underrightarrow"
    | "\\xrightarrow"
    | "\\cdrightarrow" => "→"
    "\\overbrace" => "⏞"
    "\\underbrace" => "⏟"
    "\\overbracket" => "⎴"
    "\\underbracket" => "⎵"
    "\\overleftrightarrow" | "\\underleftrightarrow" | "\\xleftrightarrow" =>
      "↔"
    "\\Overrightarrow" | "\\xRightarrow" => "⇒"
    "\\xLeftarrow" => "⇐"
    "\\xLeftrightarrow" => "⇔"
    "\\xmapsto" => "↦"
    "\\xlongequal" | "\\cdlongequal" => "="
    _ => @backend.resolve_symbol(label)
  }
  element("mo", children=[text_node(value)], attributes=[("stretchy", "true")])
}

///|
fn measurement(value : @katex.Measurement) -> String {
  match @backend.em_value(value) {
    Some(em) if value.unit == "mu" => "\{em}em"
    _ => "\{value.number}\{value.unit}"
  }
}

///|
fn size_multiplier(size : Int) -> String {
  "\{@backend.katex_size_multiplier(size)}em"
}

///|
fn contains_ascii_digit(value : String) -> Bool {
  for character in value {
    guard character >= '0' && character <= '9' else { continue }
    return true
  }
  false
}

///|
fn verb_text(value : String, star : Bool) -> String {
  value.replace_all(old=" ", new=if star { "␣" } else { "\u{00A0}" })
}
