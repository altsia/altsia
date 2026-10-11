///|
priv struct CharacterMetrics {
  depth : Double
  height : Double
  italic : Double
  skew : Double
  width : Double
}

///|
fn Options::metric(self : Options, name : String) -> Double {
  let index = if self.size >= 5 { 0 } else if self.size >= 3 { 1 } else { 2 }
  if name == "cssEmPerMu" {
    self.metric("quad") / 18.0
  } else {
    global_metric_data.get(name).map_or(0.0, values => values[index])
  }
}

///|
fn unicode_script(code : Int) -> String? {
  if (code >= 0x0100 && code <= 0x024f) || (code >= 0x0300 && code <= 0x036f) {
    Some("latin")
  } else if code >= 0x0400 && code <= 0x04ff {
    Some("cyrillic")
  } else if code >= 0x0530 && code <= 0x058f {
    Some("armenian")
  } else if code >= 0x0900 && code <= 0x109f {
    Some("brahmic")
  } else if code >= 0x10a0 && code <= 0x10ff {
    Some("georgian")
  } else if (code >= 0x3000 && code <= 0x30ff) ||
    (code >= 0x4e00 && code <= 0x9faf) ||
    (code >= 0xff00 && code <= 0xff60) {
    Some("cjk")
  } else if code >= 0xac00 && code <= 0xd7af {
    Some("hangul")
  } else {
    None
  }
}

///|
fn character_metrics(
  character : String,
  font : String,
  mode : @katex.Mode,
) -> CharacterMetrics? {
  guard !character.is_empty() else { None }
  let code = character[0].to_int()
  let mut metrics = character_metric_data.get((font, code))
  if metrics is None {
    if extra_character_map.get(code) is Some(other) {
      metrics = character_metric_data.get((font, other))
    }
  }
  if metrics is None && mode == Text && unicode_script(code) is Some(_) {
    metrics = character_metric_data.get((font, 77))
  }
  metrics.map(values => {
    depth: values[0],
    height: values[1],
    italic: values[2],
    skew: values[3],
    width: values[4],
  })
}
