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
