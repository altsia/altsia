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
fn raw_term_source(source : String, node : S) -> String {
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
fn trim_stage1_text_edges(value : String) -> String {
  let (left, right) = trim_segment_bounds(
    value,
    0,
    value.length(),
    trim_left=true,
    trim_right=true,
  )
  if left >= right {
    ""
  } else {
    value.unsafe_substring(start=left, end=right)
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
fn range_intersects_node(node : S, range_start : Int, range_end : Int) -> Bool {
  let loc = node.loc()
  loc.end_offset > range_start && loc.start_offset < range_end
}

///|
fn selected_node_bounds(
  nodes : Array[S],
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
fn state_before_index(nodes : Array[S], index : Int) -> (Bool, Bool) {
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
fn is_fmt_skip_directive(node : S) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-skip", _)], _, _) => true
    _ => false
  }
}

///|
fn is_fmt_off_directive(node : S) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-off", _)], _, _) => true
    _ => false
  }
}

///|
fn is_fmt_on_directive(node : S) -> Bool {
  match node {
    App([Text("%", _), Text("altsia-fmt-on", _)], _, _) => true
    _ => false
  }
}

///|
fn is_template_definition_app(args : Array[S]) -> Bool {
  match args {
    [Text("λ", _), Text(_, _), App(_, _, _), ..] => true
    _ => false
  }
}

///|
fn contains_fmt_toggle(node : S) -> Bool {
  if is_fmt_on_directive(node) || is_fmt_off_directive(node) {
    return true
  }
  match node {
    App(args, _, _) => args.iter().any(fn(child) { contains_fmt_toggle(child) })
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
priv struct RenderPart {
  text : String
  gap_before : AppGap
  is_nested : Bool
  is_multiline : Bool
  display_width : Int
}

///|
fn make_render_part(
  text : String,
  is_nested : Bool,
  gap_before? : AppGap = Tight,
) -> RenderPart {
  RenderPart::{
    text,
    gap_before,
    is_nested,
    is_multiline: text.contains("\n"),
    display_width: string_display_width(text),
  }
}

///|
fn render_parts_line(parts : ArrayView[RenderPart]) -> String {
  let mut line = ""
  for i in 0..<parts.length() {
    let part = parts[i]
    if i > 0 && part.gap_before == Space {
      line = line + " " + part.text
    } else {
      line = line + part.text
    }
  }
  line
}

///|
fn render_parts_display_width(parts : ArrayView[RenderPart]) -> Int {
  let mut width = 0
  for i in 0..<parts.length() {
    if i > 0 && parts[i].gap_before == Space {
      width += 1
    }
    width += parts[i].display_width
  }
  width
}

///|
fn append_render_parts(
  target : Array[RenderPart],
  source : ArrayView[RenderPart],
) -> Unit {
  for part in source {
    target.push(part)
  }
}

///|
fn canonical_gap_before(args : Array[S], gaps : Array[AppGap], index : Int) -> AppGap {
  if index == 0 {
    return Tight
  }
  let raw_gap = gaps[index - 1]
  if raw_gap == Space {
    return Space
  }
  match (args[index - 1], args[index]) {
    (App(_, _, _), App(_, _, _)) => Space
    _ => Tight
  }
}

///|
fn normalize_node_canonical(
  node : S,
  source : String,
  max_width : Int,
  fmt_enabled : Bool,
) -> String {
  if !fmt_enabled {
    match node {
      Text(_, _) | QuoteBlock(_, _) | QuoteInline(_, _) =>
        raw_term_source(source, node)
      App(args, gaps, _) =>
        if contains_fmt_toggle(node) {
          if is_template_definition_app(args) {
            normalize_template_app(
              args,
              gaps,
              source,
              max_width,
              fmt_enabled=false,
            )
          } else {
            normalize_app_with_skip(
              args,
              gaps,
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
      Text(text, _) => escape_text(trim_stage1_text_edges(text))
      QuoteBlock(_, _) => node.to_source()
      QuoteInline(_, _) => node.to_source()
      App(args, gaps, _) =>
        if is_template_definition_app(args) {
          normalize_template_app(
            args,
            gaps,
            source,
            max_width,
            fmt_enabled=true,
          )
        } else {
          normalize_app_with_skip(
            args,
            gaps,
            source,
            max_width,
            fmt_enabled_init=true,
          )
        }
    }
  }
}

///|
fn render_inline_app(parts : Array[RenderPart], max_width : Int) -> String {
  let single_line_content = render_parts_line(parts)
  let single_line = "(" + single_line_content + ")"
  if render_parts_display_width(parts) + 2 <= max_width {
    return single_line
  }
  if !parts.iter().any(fn(part) { part.is_nested }) {
    return single_line
  }
  let mut first_nested = -1
  for i in 0..<parts.length() {
    if parts[i].is_nested {
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
    "(" + render_parts_line(parts[:first_nested])
  }
  let groups : Array[Array[RenderPart]] = []
  let mut current_group : Array[RenderPart] = [parts[first_nested]]
  for i in (first_nested + 1)..<parts.length() {
    if parts[i].is_nested {
      groups.push(current_group)
      current_group = [parts[i]]
    } else {
      current_group.push(parts[i])
    }
  }
  groups.push(current_group)

  let content_max = max_width - 2 // reserve 2 spaces indentation
  let packed_lines : Array[String] = []
  let mut current_line_parts : Array[RenderPart] = []
  let mut current_line_width = 0
  for group in groups {
    if group.iter().any(fn(part) { part.is_multiline }) {
      if !current_line_parts.is_empty() {
        packed_lines.push(render_parts_line(current_line_parts))
        current_line_parts = []
        current_line_width = 0
      }
      packed_lines.push(render_parts_line(group))
      continue
    }
    let group_width = render_parts_display_width(group)
    if current_line_parts.is_empty() {
      current_line_parts = group
      current_line_width = group_width
      continue
    }
    let gap_width = if group[0].gap_before == Space { 1 } else { 0 }
    let candidate_width = current_line_width + gap_width + group_width
    if candidate_width <= content_max {
      append_render_parts(current_line_parts, group)
      current_line_width = candidate_width
    } else {
      packed_lines.push(render_parts_line(current_line_parts))
      current_line_parts = group
      current_line_width = group_width
    }
  }
  if !current_line_parts.is_empty() {
    packed_lines.push(render_parts_line(current_line_parts))
  }
  let last_line_index = packed_lines.length() - 1
  packed_lines[last_line_index] = packed_lines[last_line_index] + " )"
  let indented_lines = packed_lines.map(fn(line) { indent_block(line, "  ") })
  header + "\n" + indented_lines.join("\n")
}

///|
fn normalize_app_with_skip(
  args : Array[S],
  gaps : Array[AppGap],
  source : String,
  max_width : Int,
  fmt_enabled_init? : Bool = true,
) -> String {
  let inline_parts : Array[RenderPart] = []
  let blocks : Array[String] = []
  let mut skip_next = false
  let mut fmt_enabled = fmt_enabled_init
  for i in 0..<args.length() {
    let arg = args[i]
    let gap_before = canonical_gap_before(args, gaps, i)
    if is_fmt_on_directive(arg) {
      inline_parts.push(
        make_render_part(
          normalize_node_canonical(arg, source, max_width, true),
          false,
          gap_before~,
        ),
      )
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(arg) {
      inline_parts.push(
        make_render_part(
          normalize_node_canonical(arg, source, max_width, true),
          false,
          gap_before~,
        ),
      )
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
        QuoteBlock(_, _) => blocks.push(rendered)
        App(_, _, _) => inline_parts.push(make_render_part(rendered, true, gap_before~))
        _ => inline_parts.push(make_render_part(rendered, false, gap_before~))
      }
      continue
    }
    if skip_next {
      match arg {
        QuoteBlock(_, _) => blocks.push(raw_term_source(source, arg))
        App(_, _, _) =>
          inline_parts.push(
            make_render_part(raw_term_source(source, arg), true, gap_before~),
          )
        _ =>
          inline_parts.push(
            make_render_part(raw_term_source(source, arg), false, gap_before~),
          )
      }
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      inline_parts.push(
        make_render_part(
          normalize_node_canonical(arg, source, max_width, true),
          false,
          gap_before~,
        ),
      )
      skip_next = true
      continue
    }
    match arg {
      QuoteBlock(_, _) =>
        blocks.push(normalize_node_canonical(arg, source, max_width, true))
      App(_, _, _) =>
        inline_parts.push(
          make_render_part(
            normalize_node_canonical(arg, source, max_width, true),
            true,
            gap_before~,
          ),
        )
      _ =>
        inline_parts.push(
          make_render_part(
            normalize_node_canonical(arg, source, max_width, true),
            false,
            gap_before~,
          ),
        )
    }
  }
  let app_line = render_inline_app(inline_parts, max_width)
  if blocks.is_empty() {
    app_line
  } else {
    app_line + "\n" + blocks.join("\n")
  }
}

///|
fn normalize_template_parts(
  args : Array[S],
  gaps : Array[AppGap],
  source : String,
  max_width : Int,
  fmt_enabled_init? : Bool = true,
) -> Array[(String, AppGap)] {
  let parts : Array[(String, AppGap)] = []
  let mut skip_next = false
  let mut fmt_enabled = fmt_enabled_init
  for i in 0..<args.length() {
    let arg = args[i]
    let gap_before = canonical_gap_before(args, gaps, i)
    if is_fmt_on_directive(arg) {
      parts.push((normalize_node_canonical(arg, source, max_width, true), gap_before))
      fmt_enabled = true
      skip_next = false
      continue
    }
    if is_fmt_off_directive(arg) {
      parts.push((normalize_node_canonical(arg, source, max_width, true), gap_before))
      fmt_enabled = false
      skip_next = false
      continue
    }
    if !fmt_enabled {
      if contains_fmt_toggle(arg) {
        parts.push((normalize_node_canonical(arg, source, max_width, false), gap_before))
      } else {
        parts.push((raw_term_source(source, arg), gap_before))
      }
      continue
    }
    if skip_next {
      parts.push((raw_term_source(source, arg), gap_before))
      skip_next = false
      continue
    }
    if is_fmt_skip_directive(arg) {
      parts.push((normalize_node_canonical(arg, source, max_width, true), gap_before))
      skip_next = true
      continue
    }
    parts.push((normalize_node_canonical(arg, source, max_width, true), gap_before))
  }
  parts
}

///|
fn render_template_parts_line(parts : ArrayView[(String, AppGap)]) -> String {
  let mut line = ""
  for i in 0..<parts.length() {
    let (part, gap_before) = parts[i]
    if i > 0 && gap_before == Space {
      line = line + " " + part
    } else {
      line = line + part
    }
  }
  line
}

///|
fn template_parts_display_width(parts : ArrayView[(String, AppGap)]) -> Int {
  let mut width = 0
  for i in 0..<parts.length() {
    let (part, gap_before) = parts[i]
    if i > 0 && gap_before == Space {
      width += 1
    }
    width += string_display_width(part)
  }
  width
}

///|
fn normalize_template_app(
  args : Array[S],
  gaps : Array[AppGap],
  source : String,
  max_width : Int,
  fmt_enabled? : Bool = true,
) -> String {
  let parts = normalize_template_parts(
    args,
    gaps,
    source,
    max_width,
    fmt_enabled_init=fmt_enabled,
  )
  let single_line_content = render_template_parts_line(parts)
  let single_line = "(" + single_line_content + ")"
  if template_parts_display_width(parts) + 2 <= max_width {
    return single_line
  }
  if parts.length() <= 3 {
    return single_line
  }
  let header = "(" + render_template_parts_line(parts[:3])
  let body_lines : Array[String] = []
  for body_part in parts[3:] {
    let (body, _) = body_part
    body_lines.push(indent_block(body, "  "))
  }
  let last_line_index = body_lines.length() - 1
  body_lines[last_line_index] = body_lines[last_line_index] + " )"
  header + "\n" + body_lines.join("\n")
}

///|
fn normalize_nodes_with_skip(
  nodes : Array[S],
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
  let nodes = Stage1::parse(source)
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
    source, start_offset, end_offset,
  )
  if range_start == range_end {
    return source
  }
  let nodes = Stage1::parse(source)
  match selected_node_bounds(nodes, range_start, range_end) {
    None => source
    Some((first_index, last_index)) => {
      let (fmt_enabled_init, skip_next_init) = state_before_index(
        nodes, first_index,
      )
      let selected_nodes : Array[S] = []
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
      let suffix = source.unsafe_substring(
        start=last_loc.end_offset,
        end=source.length(),
      )
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
pub fn altsia_normalize_range_diagnostics(
  source : String,
  start_offset : Int,
  end_offset : Int,
  language? : String = default_language,
  max_width? : Int = default_max_width,
) -> Result[String, Array[RenderError]] {
  try
    altsia_normalize_range_impl(source, start_offset, end_offset, max_width)
  catch {
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
  match
    altsia_normalize_range_diagnostics(
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
