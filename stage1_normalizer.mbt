///|
fn raw_term_source(source : String, node : SpannedS) -> String {
  let loc = node.loc()
  source.unsafe_substring(start=loc.start_offset, end=loc.end_offset)
}

///|
fn sanitize_max_width(max_width : Int) -> Int {
  if max_width < 20 { 20 } else { max_width }
}

///|
fn is_fmt_skip_directive(node : SpannedS) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-skip", _)], _) => true
    _ => false
  }
}

///|
fn is_template_definition_app(args : Array[SpannedS]) -> Bool {
  match args {
    [Text("λ", _), Text(_, _), App(_, _), .. _] => true
    _ => false
  }
}

///|
fn indent_block(text : String, prefix : String) -> String {
  text
  .split("\n")
  .map(StringView::to_string)
  .map(fn(line) { prefix + line })
  .join("\n")
}

///|
fn normalize_node_canonical(
  node : SpannedS,
  source : String,
  max_width : Int,
) -> String {
  match node {
    Text(_, _) => SpannedS::erase_span(node).to_source()
    Quote(_, _) => SpannedS::erase_span(node).to_source()
    App(args, _) =>
      if is_template_definition_app(args) {
        normalize_template_app(args, source, max_width)
      } else {
        normalize_app_with_skip(args, source, max_width)
      }
  }
}

///|
fn normalize_app_with_skip(
  args : Array[SpannedS],
  source : String,
  max_width : Int,
) -> String {
  let inline_parts : Array[String] = []
  let blocks : Array[String] = []
  let mut skip_next = false
  for arg in args {
    if skip_next {
      match arg {
        Quote(_, _) => blocks.push(raw_term_source(source, arg))
        _ => inline_parts.push(raw_term_source(source, arg))
      }
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      inline_parts.push(normalize_node_canonical(arg, source, max_width))
      skip_next = true
      continue
    }
    match arg {
      Quote(_, _) => blocks.push(normalize_node_canonical(arg, source, max_width))
      _ => inline_parts.push(normalize_node_canonical(arg, source, max_width))
    }
  }
  let app_line = "(" + inline_parts.join(" ") + ")"
  if blocks.is_empty() {
    app_line
  } else {
    app_line + "\n" + blocks.join("\n")
  }
}

///|
fn normalize_template_parts(
  args : Array[SpannedS],
  source : String,
  max_width : Int,
) -> Array[String] {
  let parts : Array[String] = []
  let mut skip_next = false
  for arg in args {
    if skip_next {
      parts.push(raw_term_source(source, arg))
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      parts.push(normalize_node_canonical(arg, source, max_width))
      skip_next = true
      continue
    }
    parts.push(normalize_node_canonical(arg, source, max_width))
  }
  parts
}

///|
fn normalize_template_app(
  args : Array[SpannedS],
  source : String,
  max_width : Int,
) -> String {
  let parts = normalize_template_parts(args, source, max_width)
  let single_line = "(" + parts.join(" ") + ")"
  if single_line.length() <= max_width {
    return single_line
  }
  if parts.length() <= 3 {
    return single_line
  }
  let header = "(" + parts[0] + " " + parts[1] + " " + parts[2]
  let body_lines : Array[String] = []
  for body in parts[3:] {
    body_lines.push(indent_block(body, "  "))
  }
  let last_line_index = body_lines.length() - 1
  body_lines[last_line_index] = body_lines[last_line_index] + " )"
  header + "\n" + body_lines.join("\n")
}

///|
fn normalize_nodes_with_skip(
  nodes : Array[SpannedS],
  source : String,
  max_width : Int,
) -> String {
  let rendered : Array[String] = []
  let mut skip_next = false
  for node in nodes {
    if skip_next {
      rendered.push(raw_term_source(source, node))
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(node) {
      rendered.push(normalize_node_canonical(node, source, max_width))
      skip_next = true
      continue
    }
    rendered.push(normalize_node_canonical(node, source, max_width))
  }
  rendered.join("\n\n")
}

///|
fn altsia_normalize_impl(source : String, max_width : Int) -> String raise {
  let max_width = sanitize_max_width(max_width)
  let nodes = Stage1::parse_spanned(source)
  normalize_nodes_with_skip(nodes, source, max_width)
}

///|
pub fn Stage1::normalize(source : String, max_width? : Int = 80) -> String raise {
  altsia_normalize_impl(source, max_width)
}

///|
pub fn altsia_normalize_raise(
  source : String,
  max_width? : Int = 80,
) -> String raise {
  altsia_normalize_impl(source, max_width)
}

///|
pub fn altsia_normalize_diagnostics(
  source : String,
  language? : String = "en",
  max_width? : Int = 80,
) -> Result[String, Array[RenderError]] {
  try altsia_normalize_impl(source, max_width) catch {
    err => Err([render_error(err, source, language)])
  } noraise {
    normalized => Ok(normalized)
  }
}

///|
pub fn altsia_normalize_result(
  source : String,
  language? : String = "en",
  max_width? : Int = 80,
) -> Result[String, Array[String]] {
  match altsia_normalize_diagnostics(source, language~, max_width~) {
    Ok(normalized) => Ok(normalized)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_normalize(
  source : String,
  language? : String = "en",
  max_width? : Int = 80,
) -> String {
  match altsia_normalize_result(source, language~, max_width~) {
    Ok(normalized) => normalized
    Err(errors) => errors.join("\n")
  }
}
