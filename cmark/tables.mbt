//! Lookup helpers over the generated tables in the `*_data.mbt` files.

///|
/// Returns the expansion of the entity whose name is exactly `bytes`, or `None`.
fn get_entity(bytes : BytesView) -> String? {
  let mut lo = 0
  let mut hi = entities_table.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let cmp = bytes.lexical_compare(entities_table[mid].0.exact_view())
    guard cmp != 0 else { return Some(entities_table[mid].1) }
    if cmp < 0 {
      hi = mid - 1
    } else {
      lo = mid + 1
    }
  }
  None
}

///|
fn is_ascii_punctuation(c : Int32) -> Bool {
  (0x21 <= c && c <= 0x2F) ||
  (0x3A <= c && c <= 0x40) ||
  (0x5B <= c && c <= 0x60) ||
  (0x7B <= c && c <= 0x7E)
}

///|
fn is_punctuation(c : Int32) -> Bool {
  guard c >= 128 else { return is_ascii_punctuation(c) }
  match unicode_punctuation_bounds.binary_search(c) {
    Ok(index) => index % 2 == 0
    Err(index) => index % 2 == 1
  }
}
