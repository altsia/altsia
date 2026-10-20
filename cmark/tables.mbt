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
fn is_ascii_punctuation(c : Int) -> Bool {
  c < 128 && (punct_masks_ascii[c / 16] & (1 << (c & 15))) != 0
}

///|
fn is_punctuation(c : Int) -> Bool {
  guard c >= 128 else { return is_ascii_punctuation(c) }
  guard c <= 0x1FBCA else { return false }
  let high = c / 16
  match punct_tab.binary_search(high) {
    Ok(index) => (punct_masks[index] & (1 << (c & 15))) != 0
    Err(_) => false
  }
}

