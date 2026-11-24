///|
/// General-purpose helpers shared by the backends.
///
/// Joins arrays with `separator` between them.
fn[T] interleave(groups : Array[Array[T]], separator : T) -> Array[T] {
  groups.map(g => [separator, ..g]).flatten()[1:].to_owned()
}

///|
/// The rendered width of each column: the widest cell in the header and
/// the body rows. Columns beyond `header` or a row are treated as empty.
fn table_cell_widths(
  header : Array[String],
  rows : Array[Array[String]],
  count : Int32,
  measure~ : (String) -> Int32 = String::length,
) -> Array[Int32] {
  let widths = Array::make(count, 0)
  for i in 0..<count {
    widths[i] = measure(header[i])
  }
  for row in rows {
    for i in 0..<count {
      guard i < row.length() else { continue }
      widths[i] = widths[i].max(measure(row[i]))
    }
  }
  widths
}
