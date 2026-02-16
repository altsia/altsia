///|
pub fn is_wide_east_asian(ch : Char) -> Bool {
  let cp = ch.to_int()
  (cp >= 0x1100 && cp <= 0x115F) || // Hangul Jamo init. consonants
  cp == 0x2329 ||
  cp == 0x232A ||
  (cp >= 0x2E80 && cp <= 0xA4CF) || // CJK ... Yi
  (cp >= 0xAC00 && cp <= 0xD7A3) || // Hangul syllables
  (cp >= 0xF900 && cp <= 0xFAFF) || // CJK compatibility ideographs
  (cp >= 0xFE10 && cp <= 0xFE19) || // Vertical forms
  (cp >= 0xFE30 && cp <= 0xFE6F) || // CJK compatibility forms
  (cp >= 0xFF00 && cp <= 0xFF60) || // Fullwidth forms
  (cp >= 0xFFE0 && cp <= 0xFFE6) || // Fullwidth symbols
  (cp >= 0x1F300 && cp <= 0x1FAFF) || // Most emoji blocks
  (cp >= 0x20000 && cp <= 0x2FFFD) ||
  (cp >= 0x30000 && cp <= 0x3FFFD)
}

///|
pub fn char_display_width(ch : Char) -> Int {
  if is_wide_east_asian(ch) {
    2
  } else {
    1
  }
}

///|
pub fn string_display_width(s : String) -> Int {
  let mut total = 0
  for ch in s.iter() {
    total += char_display_width(ch)
  }
  total
}
