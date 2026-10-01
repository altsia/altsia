///|
fn render_array(node : @katex.ParseNode, state : RenderState) -> String {
  match node {
    Array(body~, columns~, hlines_before_row~, ..) if has_hlines(
        hlines_before_row,
      ) => render_array_table(body, columns, hlines_before_row, state)
    Array(body~, columns~, column_separation_type=None, ..) =>
      render_mat_body(body, columns, None, state)
    Array(
      body~,
      column_separation_type=Some(@katex.ColumnSeparationType::AlignSeparation),
      ..
    ) => render_aligned(body, state)
    Array(
      column_separation_type=Some(
        @katex.ColumnSeparationType::AlignAtSeparation
      ),
      ..
    ) => unsupported_comment("alignat")
    Array(
      column_separation_type=Some(@katex.ColumnSeparationType::GatherSeparation),
      ..
    ) => unsupported_comment("gathered")
    Array(
      body~,
      columns~,
      column_separation_type=Some(@katex.ColumnSeparationType::SmallSeparation),
      ..
    ) => render_substack(body, columns, state)
    Array(
      column_separation_type=Some(@katex.ColumnSeparationType::CdSeparation),
      ..
    ) => unsupported_comment("cd")
    _ => ""
  }
}

///|
fn has_hlines(hlines_before_row : Array[Array[Bool]]) -> Bool {
  hlines_before_row.any(row => row.length() > 0)
}

///|
fn render_leftright_array(
  array : @katex.ParseNode,
  left : String,
  right : String,
  state : RenderState,
) -> String {
  match array {
    Array(body~, columns~, hlines_before_row~, ..) if has_hlines(
        hlines_before_row,
      ) =>
      wrap_lr(
        render_array_table(body, columns, hlines_before_row, state),
        left,
        right,
      )
    Array(body~, columns~, column_separation_type=None, ..) if is_left_brace(
        left,
      ) &&
      columns.map_or(false, all_l) => render_cases(body, state)
    Array(body~, columns~, hlines_before_row~, column_separation_type=None, ..) if columns.map_or(
        false, contains_separator,
      ) =>
      wrap_lr(
        render_array_table(body, columns, hlines_before_row, state),
        left,
        right,
      )
    Array(body~, columns~, column_separation_type=None, ..) =>
      render_mat_body(body, columns, Some(mat_delim(left, right)), state)
    Array(
      body~,
      columns~,
      column_separation_type=Some(@katex.ColumnSeparationType::SmallSeparation),
      ..
    ) => {
      // `\left( \substack{...} \right)`: the stack has no delimiter of
      // its own, so the surrounding `lr` is preserved.
      let content = render_substack(body, columns, state)
      wrap_lr(content, left, right)
    }
    _ => render_array(array, state)
  }
}

///|
/// The `mat` `delim:` argument for a `\left...\right` array: the standard
/// pairs map to a quoted symbol; mismatched or uncommon pairs pass an
/// explicit `("left", "right")` pair.
fn mat_delim(left : String, right : String) -> String {
  match (left, right) {
    ("(", ")") => "\"(\""
    ("[", "]") => "\"[\""
    ("\\{", "\\}") | ("{", "}") => "\"{\""
    ("|", "|") => "\"|\""
    ("\\|", "\\|") | ("‖", "‖") => "\"‖\""
    _ => "#(\"{left}\", \"{right}\")"
  }
}

///|
fn is_left_brace(left : String) -> Bool {
  left == "\\{" || left == "{" || left == "\\lbrace"
}

///|
fn all_l(columns : Array[@katex.ArrayColumn]) -> Bool {
  columns.all(column => column is AlignColumn(alignment="l", ..))
}

///|
fn render_mat_body(
  body : Array[Array[@katex.ParseNode]],
  columns : Array[@katex.ArrayColumn]?,
  delim : String?,
  state : RenderState,
) -> String {
  if columns.map_or(false, contains_separator) {
    render_array_table(body, columns, [], state)
  } else {
    let rows = body.map(row => render_mat_row(row, state)).join("; ")
    guard rows != "" else { unsupported_comment("empty array") }
    let delim_arg = delim.map_or("", d => ", delim: \{d}")
    let align_arg = columns.bind(column_align_args).unwrap_or("")
    "mat(\{rows}\{delim_arg}\{align_arg})"
  }
}

///|
/// `\substack` expands to the one-column `subarray` environment; `smallmatrix`
/// (also `SmallSeparation`) has one column per row. There is no 0.15 `stack`
/// math function, so a single-column array is emitted as `mat(...)` with
/// `;`-separated rows, which renders as a compact centered stack. A
/// multi-column `smallmatrix` stays unsupported.
fn render_substack(
  body : Array[Array[@katex.ParseNode]],
  columns : Array[@katex.ArrayColumn]?,
  state : RenderState,
) -> String {
  if is_single_column(columns) {
    render_stack_rows(body, state)
  } else {
    unsupported_comment("smallmatrix")
  }
}

///|
/// A `\substack` column spec has no separators and at most one alignment
/// column; a multi-column `smallmatrix` stays unsupported.
fn is_single_column(columns : Array[@katex.ArrayColumn]?) -> Bool {
  columns.map_or(true, cols => {
    cols.length() <= 1 && cols.all(col => col is AlignColumn(..))
  })
}

///|
fn render_stack_rows(
  body : Array[Array[@katex.ParseNode]],
  state : RenderState,
) -> String {
  let rows = body
    .map(row => row.map(cell => render_cell(cell, state)).join(", "))
    .join("; ")
  guard rows != "" else { unsupported_comment("empty array") }
  "mat(\{rows})"
}

///|
/// Typst `mat` only supports a single uniform alignment, so per-column specs
/// are emitted only when every column agrees.
fn column_align_args(columns : Array[@katex.ArrayColumn]) -> String? {
  let aligns = columns.map(column_align)
  guard aligns is [first, ..] else { return None }
  if aligns.all(align => align == first) && first != "center" {
    Some(", align: #\{first}")
  } else {
    None
  }
}

///|
fn column_align(column : @katex.ArrayColumn) -> String {
  match column {
    AlignColumn(alignment~, ..) => align_name(alignment)
    _ => "center"
  }
}

///|
fn contains_separator(columns : Array[@katex.ArrayColumn]) -> Bool {
  columns.any(column => column is SeparatorColumn(..))
}

///|
/// Emits an array with horizontal lines or `|` column separators as a Typst
/// `#table(...)`: cells are `[$...$]` content, `table.hline()` draws the
/// `\hline`/`\hdashline` marks (dashed for the latter), and `table.vline()`
/// draws the separator columns. Vlines are written once, with the first row:
/// a flow-placed `table.vline()` spans the whole table column (v0.15.0
/// source: `start` defaults to 0, `end` to the last row).
fn render_array_table(
  body : Array[Array[@katex.ParseNode]],
  columns : Array[@katex.ArrayColumn]?,
  hlines_before_row : Array[Array[Bool]],
  state : RenderState,
) -> String {
  let ncols = match columns {
    Some(cols) => cols.filter(col => col is AlignColumn(..)).length()
    None =>
      match body {
        [row, ..] => row.length()
        _ => 0
      }
  }
  let vline_boundaries : Set[Int] = Set([])
  let aligns : Array[String] = []
  for col in columns.unwrap_or([]) {
    match col {
      AlignColumn(alignment~, ..) => aligns.push(align_name(alignment))
      SeparatorColumn(..) => vline_boundaries.add(aligns.length())
    }
  }
  let lines : Array[String] = [
    "#table(",
    "  columns: \{ncols},",
    "  align: \{render_table_align(aligns)},",
    "  stroke: none,",
  ]
  for i in 0..<body.length() {
    if hlines_before_row.get(i) is Some(row_lines) && !row_lines.is_empty() {
      lines.push("  \{render_table_hline(row_lines)},")
    }
    if i == 0 {
      lines.push(
        "  \{table_row(body[0], vline_boundaries, ncols, state).join(", ")},",
      )
    } else {
      lines.push("  \{row_cells(body[i], state).join(", ")},")
    }
  }
  if hlines_before_row.get(body.length()) is Some(row_lines) &&
    !row_lines.is_empty() {
    lines.push("  \{render_table_hline(row_lines)},")
  }
  lines.push(")")
  lines.join("\n")
}

///|
fn row_cells(
  row : Array[@katex.ParseNode],
  state : RenderState,
) -> Array[String] {
  row.map(cell => "[$\{render_cell(cell, state)}$]")
}

///|
fn table_row(
  row : Array[@katex.ParseNode],
  vline_boundaries : Set[Int],
  ncols : Int,
  state : RenderState,
) -> Array[String] {
  let cells = row.mapi((j, cell) => {
    let content = "[$\{render_cell(cell, state)}$]"
    if vline_boundaries.contains(j) {
      "table.vline(), \{content}"
    } else {
      content
    }
  })
  if vline_boundaries.contains(ncols) {
    cells.push("table.vline()")
  }
  cells
}

///|
fn align_name(alignment : String) -> String {
  match alignment {
    "l" => "left"
    "r" => "right"
    _ => "center"
  }
}

///|
fn render_table_align(aligns : Array[String]) -> String {
  if aligns.all(a => a == "center") {
    "center"
  } else {
    "(\{aligns.join(", ")})"
  }
}

///|
fn render_table_hline(row_lines : Array[Bool]) -> String {
  if row_lines.any(line => line) {
    "table.hline(stroke: (thickness: 0.5pt, dash: (2pt, 1pt)))"
  } else {
    "table.hline()"
  }
}

///|
fn render_mat_row(row : Array[@katex.ParseNode], state : RenderState) -> String {
  row.map(cell => render_cell(cell, state)).join(", ")
}

///|
fn render_cell(cell : @katex.ParseNode, state : RenderState) -> String {
  let rendered = render_node(cell, state)
  if rendered == "" {
    "zws"
  } else {
    rendered
  }
}

///|
/// Typst `cases` takes one variadic argument per branch (row); cells within a
/// branch are aligned with `&`.
fn render_cases(
  body : Array[Array[@katex.ParseNode]],
  state : RenderState,
) -> String {
  let items = body.map(row => {
    row.map(cell => render_cell(cell, state)).join(" & ")
  })
  "cases(\{items.join(", ")})"
}

///|
/// Aligned rows: cells joined with `&`, rows with `\ `. Empty cells render
/// as nothing — the alignment point alone suffices (`&  &`).
fn render_aligned(
  body : Array[Array[@katex.ParseNode]],
  state : RenderState,
) -> String {
  body
  .map(row => row.map(cell => render_node(cell, state)).join(" & "))
  .join(" \\ ")
}
