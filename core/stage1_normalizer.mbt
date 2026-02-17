///|
let default_max_width : Int = 80

///|
let default_language : String = "en"

///|
pub(all) suberror Stage1NormalizeError {
  InvalidRange(
    start_offset~ : Int,
    end_offset~ : Int,
    source_length~ : Int,
    loc~ : SourceLoc
  )
} derive(Eq, Show)

///|
fn raw_term_source(source : String, node : SpannedS) -> String {
  let loc = node.loc()
  source.unsafe_substring(start=loc.start_offset, end=loc.end_offset)
}

///|
fn sanitize_max_width(max_width : Int) -> Int {
  if max_width < 20 {
    20
  } else {
    max_width
  }
}

///|
fn validate_normalize_range(
  source : String,
  start_offset : Int,
  end_offset : Int,
) -> (Int, Int) raise {
  let source_length = source.length()
  if start_offset >= 0 &&
    end_offset >= 0 &&
    start_offset <= source_length &&
    end_offset <= source_length &&
    start_offset <= end_offset {
    return (start_offset, end_offset)
  }
  let loc_offset = if start_offset < 0 {
    0
  } else if start_offset > source_length {
    source_length
  } else {
    start_offset
  }
  raise Stage1NormalizeError::InvalidRange(
    start_offset~,
    end_offset~,
    source_length~,
    loc=source_loc_from_offsets(source, loc_offset, loc_offset),
  )
}

///|
fn range_intersects_node(node : SpannedS, range_start : Int, range_end : Int) -> Bool {
  let loc = node.loc()
  loc.end_offset > range_start && loc.start_offset < range_end
}

///|
fn selected_node_bounds(
  nodes : Array[SpannedS],
  range_start : Int,
  range_end : Int,
) -> (Int, Int)? {
  let mut first = -1
  let mut last = -1
  for i in 0..<nodes.length() {
    if range_intersects_node(nodes[i], range_start, range_end) {
      if first == -1 {
        first = i
      }
      last = i
    }
  }
  if first == -1 {
    None
  } else {
    Some((first, last))
  }
}

///|
fn state_before_index(
  nodes : Array[SpannedS],
  index : Int,
) -> (Bool, Bool) {
  let mut fmt_enabled = true
  let mut skip_next = false
  for i in 0..<index {
    let node = nodes[i]
    if is_fmt_on_directive(node) {
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(node) {
      fmt_enabled = false
      skip_next = false
      continue
    }
    if !fmt_enabled {
      continue
    }
    if skip_next {
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(node) {
      skip_next = true
      continue
    }
  }
  (fmt_enabled, skip_next)
}

///|
fn is_fmt_skip_directive(node : SpannedS) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-skip", _)], _) => true
    _ => false
  }
}

///|
fn is_fmt_off_directive(node : SpannedS) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-off", _)], _) => true
    _ => false
  }
}

///|
fn is_fmt_on_directive(node : SpannedS) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-on", _)], _) => true
    _ => false
  }
}

///|
fn is_template_definition_app(args : Array[SpannedS]) -> Bool {
  match args {
    [Text("λ", _), Text(_, _), App(_, _), ..] => true
    _ => false
  }
}

///|
fn contains_fmt_toggle(node : SpannedS) -> Bool {
  if is_fmt_on_directive(node) || is_fmt_off_directive(node) {
    return true
  }
  match node {
    App(args, _) => args.iter().any(fn(child) { contains_fmt_toggle(child) })
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
  fmt_enabled : Bool,
) -> String {
  if !fmt_enabled {
    match node {
      Text(_, _) | Quote(_, _) => raw_term_source(source, node)
      App(args, _) =>
        if contains_fmt_toggle(node) {
          if is_template_definition_app(args) {
            normalize_template_app(args, source, max_width, fmt_enabled=false)
          } else {
            normalize_app_with_skip(
              args,
              source,
              max_width,
              fmt_enabled_init=false,
            )
          }
        } else {
          raw_term_source(source, node)
        }
    }
  } else {
    match node {
      Text(_, _) => SpannedS::erase_span(node).to_source()
      Quote(_, _) => SpannedS::erase_span(node).to_source()
      App(args, _) =>
        if is_template_definition_app(args) {
          normalize_template_app(args, source, max_width, fmt_enabled=true)
        } else {
          normalize_app_with_skip(
            args,
            source,
            max_width,
            fmt_enabled_init=true,
          )
        }
    }
  }
}

///|
fn render_inline_app(
  parts : Array[String],
  nested_flags : Array[Bool],
  max_width : Int,
) -> String {
  let single_line = "(" + parts.join(" ") + ")"
  if string_display_width(single_line) <= max_width {
    return single_line
  }
  if !nested_flags.contains(true) {
    return single_line
  }
  let mut first_nested = -1
  for i in 0..<nested_flags.length() {
    if nested_flags[i] {
      first_nested = i
      break
    }
  }
  if first_nested == -1 {
    return single_line
  }
  let header = if first_nested == 0 {
    "("
  } else {
    "(" + parts[:first_nested].join(" ")
  }
  // Build groups at nested-app boundaries; then pack multiple groups per line
  // as long as line width allows.
  let groups : Array[String] = []
  let mut current_group = parts[first_nested]
  for i in (first_nested + 1)..<parts.length() {
    if nested_flags[i] {
      groups.push(current_group)
      current_group = parts[i]
    } else {
      current_group = current_group + " " + parts[i]
    }
  }
  groups.push(current_group)

  let content_max = max_width - 2 // reserve 2 spaces indentation
  let packed_lines : Array[String] = []
  let mut current_line = ""
  for group in groups {
    if current_line == "" {
      current_line = group
      continue
    }
    let candidate = current_line + " " + group
    if string_display_width(candidate) <= content_max {
      current_line = candidate
    } else {
      packed_lines.push(current_line)
      current_line = group
    }
  }
  if current_line != "" {
    packed_lines.push(current_line)
  }
  let last_line_index = packed_lines.length() - 1
  packed_lines[last_line_index] = packed_lines[last_line_index] + " )"
  let indented_lines = packed_lines.map(fn(line) { "  " + line })
  header + "\n" + indented_lines.join("\n")
}

///|
fn normalize_app_with_skip(
  args : Array[SpannedS],
  source : String,
  max_width : Int,
  fmt_enabled_init? : Bool = true,
) -> String {
  let inline_parts : Array[String] = []
  let inline_nested : Array[Bool] = []
  let blocks : Array[String] = []
  let mut skip_next = false
  let mut fmt_enabled = fmt_enabled_init
  for arg in args {
    if is_fmt_on_directive(arg) {
      inline_parts.push(normalize_node_canonical(arg, source, max_width, true))
      inline_nested.push(false)
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(arg) {
      inline_parts.push(normalize_node_canonical(arg, source, max_width, true))
      inline_nested.push(false)
      fmt_enabled = false
      skip_next = false
      continue
    }
    if !fmt_enabled {
      let rendered = if contains_fmt_toggle(arg) {
        normalize_node_canonical(arg, source, max_width, false)
      } else {
        raw_term_source(source, arg)
      }
      match arg {
        Quote(_, _) => blocks.push(rendered)
        App(_, _) => {
          inline_parts.push(rendered)
          inline_nested.push(true)
        }
        _ => {
          inline_parts.push(rendered)
          inline_nested.push(false)
        }
      }
      continue
    }
    if skip_next {
      match arg {
        Quote(_, _) => blocks.push(raw_term_source(source, arg))
        App(_, _) => {
          inline_parts.push(raw_term_source(source, arg))
          inline_nested.push(true)
        }
        _ => {
          inline_parts.push(raw_term_source(source, arg))
          inline_nested.push(false)
        }
      }
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      inline_parts.push(normalize_node_canonical(arg, source, max_width, true))
      inline_nested.push(false)
      skip_next = true
      continue
    }
    match arg {
      Quote(_, _) =>
        blocks.push(normalize_node_canonical(arg, source, max_width, true))
      App(_, _) => {
        inline_parts.push(normalize_node_canonical(arg, source, max_width, true))
        inline_nested.push(true)
      }
      _ => {
        inline_parts.push(normalize_node_canonical(arg, source, max_width, true))
        inline_nested.push(false)
      }
    }
  }
  let app_line = render_inline_app(inline_parts, inline_nested, max_width)
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
  fmt_enabled_init? : Bool = true,
) -> Array[String] {
  let parts : Array[String] = []
  let mut skip_next = false
  let mut fmt_enabled = fmt_enabled_init
  for arg in args {
    if is_fmt_on_directive(arg) {
      parts.push(normalize_node_canonical(arg, source, max_width, true))
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(arg) {
      parts.push(normalize_node_canonical(arg, source, max_width, true))
      fmt_enabled = false
      skip_next = false
      continue
    }
    if !fmt_enabled {
      if contains_fmt_toggle(arg) {
        parts.push(normalize_node_canonical(arg, source, max_width, false))
      } else {
        parts.push(raw_term_source(source, arg))
      }
      continue
    }
    if skip_next {
      parts.push(raw_term_source(source, arg))
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      parts.push(normalize_node_canonical(arg, source, max_width, true))
      skip_next = true
      continue
    }
    parts.push(normalize_node_canonical(arg, source, max_width, true))
  }
  parts
}

///|
fn normalize_template_app(
  args : Array[SpannedS],
  source : String,
  max_width : Int,
  fmt_enabled? : Bool = true,
) -> String {
  let parts = normalize_template_parts(
    args,
    source,
    max_width,
    fmt_enabled_init=fmt_enabled,
  )
  let single_line = "(" + parts.join(" ") + ")"
  if string_display_width(single_line) <= max_width {
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
  fmt_enabled_init? : Bool = true,
  skip_next_init? : Bool = false,
) -> String {
  let rendered : Array[String] = []
  let mut skip_next = skip_next_init
  let mut fmt_enabled = fmt_enabled_init
  for node in nodes {
    if is_fmt_on_directive(node) {
      rendered.push(normalize_node_canonical(node, source, max_width, true))
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(node) {
      rendered.push(normalize_node_canonical(node, source, max_width, true))
      fmt_enabled = false
      skip_next = false
      continue
    }
    if !fmt_enabled {
      if contains_fmt_toggle(node) {
        rendered.push(normalize_node_canonical(node, source, max_width, false))
      } else {
        rendered.push(raw_term_source(source, node))
      }
      continue
    }
    if skip_next {
      rendered.push(raw_term_source(source, node))
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(node) {
      rendered.push(normalize_node_canonical(node, source, max_width, true))
      skip_next = true
      continue
    }
    rendered.push(normalize_node_canonical(node, source, max_width, true))
  }
  rendered.join("\n\n")
}

///|
fn altsia_normalize_impl(source : String, max_width : Int) -> String raise {
  let max_width = sanitize_max_width(max_width)
  let nodes = Stage1::parse_spanned(source)
  normalize_nodes_with_skip(
    nodes,
    source,
    max_width,
    fmt_enabled_init=true,
    skip_next_init=false,
  )
}

///|
fn altsia_normalize_range_impl(
  source : String,
  start_offset : Int,
  end_offset : Int,
  max_width : Int,
) -> String raise {
  let max_width = sanitize_max_width(max_width)
  let (range_start, range_end) = validate_normalize_range(
    source,
    start_offset,
    end_offset,
  )
  if range_start == range_end {
    return source
  }
  let nodes = Stage1::parse_spanned(source)
  match selected_node_bounds(nodes, range_start, range_end) {
    None => source
    Some((first_index, last_index)) => {
      let (fmt_enabled_init, skip_next_init) = state_before_index(nodes, first_index)
      let selected_nodes : Array[SpannedS] = []
      for i in first_index..<(last_index + 1) {
        selected_nodes.push(nodes[i])
      }
      let normalized_segment = normalize_nodes_with_skip(
        selected_nodes,
        source,
        max_width,
        fmt_enabled_init~,
        skip_next_init~,
      )
      let first_loc = nodes[first_index].loc()
      let last_loc = nodes[last_index].loc()
      let prefix = source.unsafe_substring(start=0, end=first_loc.start_offset)
      let suffix = source.unsafe_substring(start=last_loc.end_offset, end=source.length())
      prefix + normalized_segment + suffix
    }
  }
}

///|
pub fn Stage1::normalize(
  source : String,
  max_width? : Int = default_max_width,
) -> String raise {
  altsia_normalize_impl(source, max_width)
}

///|
pub fn altsia_normalize_raise(
  source : String,
  max_width? : Int = default_max_width,
) -> String raise {
  altsia_normalize_impl(source, max_width)
}

///|
pub fn Stage1::normalize_range(
  source : String,
  start_offset : Int,
  end_offset : Int,
  max_width? : Int = default_max_width,
) -> String raise {
  altsia_normalize_range_impl(source, start_offset, end_offset, max_width)
}

///|
pub fn altsia_normalize_range_raise(
  source : String,
  start_offset : Int,
  end_offset : Int,
  max_width? : Int = default_max_width,
) -> String raise {
  altsia_normalize_range_impl(source, start_offset, end_offset, max_width)
}

///|
pub fn altsia_normalize_diagnostics(
  source : String,
  language? : String = default_language,
  max_width? : Int = default_max_width,
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
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> Result[String, Array[String]] {
  match altsia_normalize_diagnostics(source, language~, max_width~) {
    Ok(normalized) => Ok(normalized)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_normalize(
  source : String,
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> String {
  match altsia_normalize_result(source, language~, max_width~) {
    Ok(normalized) => normalized
    Err(errors) => errors.join("\n")
  }
}

///|
pub fn altsia_normalize_range_diagnostics(
  source : String,
  start_offset : Int,
  end_offset : Int,
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> Result[String, Array[RenderError]] {
  try altsia_normalize_range_impl(source, start_offset, end_offset, max_width) catch {
    err => Err([render_error(err, source, language)])
  } noraise {
    normalized => Ok(normalized)
  }
}

///|
pub fn altsia_normalize_range_result(
  source : String,
  start_offset : Int,
  end_offset : Int,
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> Result[String, Array[String]] {
  match altsia_normalize_range_diagnostics(
    source,
    start_offset,
    end_offset,
    language~,
    max_width~,
  ) {
    Ok(normalized) => Ok(normalized)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_normalize_range(
  source : String,
  start_offset : Int,
  end_offset : Int,
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> String {
  match altsia_normalize_range_result(
    source,
    start_offset,
    end_offset,
    language~,
    max_width~,
  ) {
    Ok(normalized) => normalized
    Err(errors) => errors.join("\n")
  }
}
