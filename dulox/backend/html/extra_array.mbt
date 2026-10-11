///|
priv struct HtmlArrayRow {
  cells : Array[HtmlNode]
  height : Double
  depth : Double
  position : Double
}

///|
fn extra_array_gap(width : Double) -> HtmlNode {
  let gap = make_span(["arraycolsep"], [])
  gap.set_style("width", make_em(width))
  gap
}

///|
fn extra_array(
  input : Array[Array[@katex.ParseNode]],
  add_jot : Bool,
  array_stretch : Double,
  columns : Array[@katex.ArrayColumn]?,
  row_gaps : Array[@katex.Measurement?],
  hskip : Bool,
  hlines_before_row : Array[Array[Bool]],
  separation : @katex.ColumnSeparationType?,
  tags : Array[Array[@katex.ParseNode]?]?,
  auto_tags : Array[Bool]?,
  options : Options,
) -> HtmlNode {
  let rows : Array[HtmlArrayRow] = []
  let horizontal_lines : Array[(Double, Bool)] = []
  let rule_thickness = options
    .metric("arrayRuleWidth")
    .max(options.min_rule_thickness)
  let point = 1.0 / options.metric("ptPerEm")
  let array_col_sep = if separation == Some(@katex.SmallSeparation) {
    0.2778 * (options.with_style(4).size_multiplier / options.size_multiplier)
  } else {
    5.0 * point
  }
  let baseline_skip = if separation == Some(@katex.CdSeparation) {
    calculate_size({ number: 3.0, unit: "ex", }, options)
  } else {
    12.0 * point
  }
  let array_skip = array_stretch * baseline_skip
  let strut_height = 0.7 * array_skip
  let strut_depth = 0.3 * array_skip
  let mut total_height = 0.0
  let mut column_count = 0
  let place_lines = (lines : Array[Bool]) => {
    for index, dashed in lines {
      if index > 0 {
        total_height += 0.25
      }
      horizontal_lines.push((total_height, dashed))
    }
  }
  place_lines(hlines_before_row.get(0).unwrap_or([]))
  for row_index, input_row in input {
    let mut height = strut_height
    let mut depth = strut_depth
    column_count = column_count.max(input_row.length())
    let cells = input_row.map(cell => {
      let element = build_group(cell, options)
      height = height.max(element.height)
      depth = depth.max(element.depth)
      element
    })
    let mut gap = row_gaps
      .get(row_index)
      .unwrap_or(None)
      .map_or(0.0, size => calculate_size(size, options))
    if gap > 0.0 {
      depth = depth.max(gap + strut_depth)
      gap = 0.0
    }
    if add_jot && row_index < input.length() - 1 {
      depth += 3.0 * point
    }
    total_height += height
    rows.push({ cells, height, depth, position: total_height, })
    total_height += depth + gap
    place_lines(hlines_before_row.get(row_index + 1).unwrap_or([]))
  }
  let offset = total_height / 2.0 + options.metric("axisHeight")
  let descriptions = columns.unwrap_or([])
  let output_columns : Array[HtmlNode] = []
  let tag_spans : Array[VListChild] = []
  let has_tags = tags.map_or(false, tags => tags.any(tag => tag is Some(_))) ||
    auto_tags.map_or(false, tags => tags.any(tag => tag))
  if has_tags {
    for index, row in rows {
      let automatic = auto_tags.map_or(false, tags => {
        tags.get(index).unwrap_or(false)
      })
      let manual = tags.map_or(None, tags => tags.get(index).unwrap_or(None))
      let tag = manual.map_or_else(
        () => make_span(if automatic { ["eqn-num"] } else { [] }, [], options~),
        body => make_span([], build_expression(body, options), options~),
      )
      tag.height = row.height
      tag.depth = row.depth
      tag_spans.push(vlist_elem(tag, shift=row.position - offset))
    }
  }
  let mut column_index = 0
  let mut description_index = 0
  while column_index < column_count || description_index < descriptions.length() {
    let mut description = descriptions.get(description_index)
    let mut first_separator = true
    while description is Some(@katex.SeparatorColumn(separator~)) {
      if !first_separator {
        output_columns.push(extra_array_gap(options.metric("doubleRuleSep")))
      }
      let line = make_span(["vertical-separator"], [], options~)
      line.set_style("height", make_em(total_height))
      line.set_style("borderRightWidth", make_em(rule_thickness))
      line.set_style(
        "borderRightStyle",
        if separator == ":" {
          "dashed"
        } else {
          "solid"
        },
      )
      line.set_style("margin", "0 " + make_em(-rule_thickness / 2.0))
      let shift = total_height - offset
      if shift != 0.0 {
        line.set_style("verticalAlign", make_em(-shift))
      }
      output_columns.push(line)
      description_index += 1
      description = descriptions.get(description_index)
      first_separator = false
    }
    if column_index < column_count {
      let (alignment, pre_gap, post_gap) = if description
        is Some(@katex.AlignColumn(alignment~, pre_gap~, post_gap~)) {
        (
          alignment,
          pre_gap.unwrap_or(array_col_sep),
          post_gap.unwrap_or(array_col_sep),
        )
      } else {
        ("c", array_col_sep, array_col_sep)
      }
      if (column_index > 0 || hskip) && pre_gap != 0.0 {
        output_columns.push(extra_array_gap(pre_gap))
      }
      let cells : Array[VListChild] = []
      for row in rows {
        if row.cells.get(column_index) is Some(cell) {
          cell.height = row.height
          cell.depth = row.depth
          cells.push(vlist_elem(cell, shift=row.position - offset))
        }
      }
      let column = make_vlist("individualShift", 0.0, cells, options)
      output_columns.push(make_span(["col-align-" + alignment], [column]))
      if (column_index < column_count - 1 || hskip) && post_gap != 0.0 {
        output_columns.push(extra_array_gap(post_gap))
      }
    }
    column_index += 1
    description_index += 1
  }
  let mut table = make_span(["mtable"], output_columns)
  if !horizontal_lines.is_empty() {
    let line = make_line_span("katex-hline", options, thickness=rule_thickness)
    let dashes = make_line_span(
      "katex-hdashline",
      options,
      thickness=rule_thickness,
    )
    let elements : Array[VListChild] = [vlist_elem(table, shift=0.0)]
    for index = horizontal_lines.length() - 1; index >= 0; index = index - 1 {
      let (position, dashed) = horizontal_lines[index]
      elements.push(
        vlist_elem(if dashed { dashes } else { line }, shift=position - offset),
      )
    }
    table = make_vlist("individualShift", 0.0, elements, options)
  }
  if tag_spans.is_empty() {
    make_span(["mord"], [table], options~)
  } else {
    let tags = make_vlist("individualShift", 0.0, tag_spans, options)
    make_fragment([table, make_span(["katex-tag"], [tags], options~)])
  }
}
