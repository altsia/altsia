///|
/// Arrays render as `\begin{array}{preamble} ... \end{array}` with the column
/// preamble reconstructed from the column spec. Cells render faithfully
/// (including their per-cell style wrapper), so the environment name of the
/// original source does not need to be recovered. CD-diagram arrays render as
/// `\begin{CD}` with the arrow cells reconstructed.
fn render_array(node : @katex.ParseNode) -> String {
  match node {
    Array(
      body~,
      column_separation_type=Some(@katex.ColumnSeparationType::CdSeparation),
      ..
    ) => render_cd(body)
    Array(body~, columns~, row_gaps~, hlines_before_row~, ..) =>
      render_array_environment(body, columns, row_gaps, hlines_before_row)
    _ => ""
  }
}

///|
fn render_array_environment(
  body : Array[Array[@katex.ParseNode]],
  columns : Array[@katex.ArrayColumn]?,
  row_gaps : Array[@katex.Measurement?],
  hlines_before_row : Array[Array[Bool]],
) -> String {
  let preamble = array_preamble(columns, body)
  let builder = StringBuilder()
  builder.write_string("\\begin{array}{\{preamble}}")
  for i = 0; i < body.length(); i = i + 1 {
    write_array_hlines(builder, hlines_before_row.get(i))
    builder.write_string(render_array_row(body[i]))
    if i < body.length() - 1 {
      builder.write_string("\\\\")
      write_array_row_gap(builder, row_gaps.get(i))
    }
  }
  write_array_hlines(builder, hlines_before_row.get(body.length()))
  builder.write_string("\\end{array}")
  builder.to_string()
}

///|
fn array_preamble(
  columns : Array[@katex.ArrayColumn]?,
  body : Array[Array[@katex.ParseNode]],
) -> String {
  guard columns is Some(columns) else {
    let width = body.fold(init=0, (acc, row) => {
      if row.length() > acc {
        row.length()
      } else {
        acc
      }
    })
    return "c".repeat(width)
  }
  columns
  .map(column => {
    match column {
      @katex.ArrayColumn::AlignColumn(alignment~, ..) => alignment
      @katex.ArrayColumn::SeparatorColumn(separator~) => separator
    }
  })
  .join("")
}

///|
fn render_array_row(row : Array[@katex.ParseNode]) -> String {
  row.map(node => render_node(node)).join("&")
}

///|
fn write_array_hlines(builder : StringBuilder, hlines : Array[Bool]?) -> Unit {
  guard hlines is Some(lines) && !lines.is_empty() else { return }
  builder.write_string(if lines[0] { "\\hdashline" } else { "\\hline" })
}

///|
fn write_array_row_gap(
  builder : StringBuilder,
  gap : @katex.Measurement??,
) -> Unit {
  guard gap is Some(Some(value)) else { return }
  builder.write_string("[\{render_measurement(value)}]")
}

///|
/// CD rows are rendered cell by cell: arrow cells produce the `@>label>label>`
/// (or `@A{label}A{label}A`) syntax, plain cells their content. Empty corner
/// cells render as nothing.
fn render_cd(body : Array[Array[@katex.ParseNode]]) -> String {
  let rows = body.map(row => row.map(render_cd_cell).join("&"))
  "\\begin{CD}\{rows.join("\\\\")}\\end{CD}"
}

///|
fn render_cd_cell(cell : @katex.ParseNode) -> String {
  match cell {
    @katex.ParseNode::Styling(body=[content], ..) => render_cd_content(content)
    _ => render_node(cell)
  }
}

///|
fn render_cd_content(content : @katex.ParseNode) -> String {
  match content {
    @katex.ParseNode::XArrow(label~, body~, below~, ..) =>
      render_cd_xarrow(label, body, below)
    @katex.ParseNode::CdParent(fragment~, ..) => render_cd_parent(fragment)
    @katex.ParseNode::DelimSizing(delim="\\Vert", ..) => "@|"
    @katex.ParseNode::TextOrd(text=" ", ..) => "@."
    _ => render_node(content)
  }
}

///|
fn render_cd_xarrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
) -> String {
  match label {
    "\\\\cdleftarrow" =>
      "@<\{render_cd_label(body)}<\{below.map_or("", render_cd_label)}<"
    "\\\\cdlongequal" => "@="
    _ => "@>\{render_cd_label(body)}>\{below.map_or("", render_cd_label)}>"
  }
}

///|
/// A vertical arrow cell stores its two labels around the arrow inside a
/// `CdParent` fragment. In the CD source the labels sit between repeats of the
/// arrow character: `@A{left}A{right}A` for an upward arrow and
/// `@V{left}V{right}V` for a downward one.
fn render_cd_parent(fragment : @katex.ParseNode) -> String {
  match fragment {
    @katex.ParseNode::OrdGroup(
      body=[
        @katex.ParseNode::CdLabel(side="left", label=left, ..),
        @katex.ParseNode::DelimSizing(delim~, ..),
        @katex.ParseNode::CdLabel(side="right", label=right, ..),
      ],
      ..
    ) =>
      match delim {
        "\\uparrow" => "@A\{render_cd_label(left)}A\{render_cd_label(right)}A"
        _ => "@V\{render_cd_label(left)}V\{render_cd_label(right)}V"
      }
    _ => render_node(fragment)
  }
}

///|
/// Standalone cd nodes outside a `\begin{CD}` block: `\cr` becomes a row
/// break, and stray labels/parents render as nothing.
fn render_cd_internal(node : @katex.ParseNode) -> String {
  match node {
    @katex.ParseNode::Cr(new_line~, size~, ..) => render_cr(new_line, size)
    _ => ""
  }
}

///|
fn render_cr(new_line : Bool, size : @katex.Measurement?) -> String {
  let _ = new_line
  let size = size.map_or("", value => "[\{render_measurement(value)}]")
  "\\\\\{size}"
}

///|
fn render_cd_label(label : @katex.ParseNode) -> String {
  match label {
    @katex.ParseNode::OrdGroup(body=nodes, ..) => render_nodes(nodes)
    _ => render_node(label)
  }
}
