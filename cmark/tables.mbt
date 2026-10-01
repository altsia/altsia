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

///|
/// Returns the case-folded form of `c`, as an array of chars (0-3 entries).
fn unicase_lookup(c : Char) -> Array[Char] {
  let cp = c.to_int()
  // The table is sorted by codepoint; binary search.
  let mut lo = 0
  let mut hi = unicase_fold_table.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let (entry_cp, folds) = unicase_fold_table[mid]
    guard entry_cp != cp else { return folds }
    if entry_cp < cp {
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  // Not found: identity fold.
  [c]
}

///|
/// Returns the case-folded representation of the string.
fn unicase_fold(s : String) -> String {
  let out = StringBuilder()
  for c in s.iter() {
    for fc in unicase_lookup(c) {
      out.write_char(fc)
    }
  }
  out.to_string()
}
