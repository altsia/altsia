///|
/// Returns true when `self` is considered a CJK character by the
/// CommonMark CJK-friendly amendments specification.
fn Char::is_cjk_character(self : Char) -> Bool {
  let cp = self.to_int()
  guard cp >= 0x1100 else { return false }
  is_cjk_codepoint(cp)
}

///|
fn is_cjk_codepoint(cp : Int) -> Bool {
  guard !(cp >= 0x1100 && cp <= 0x11ff) else { return true }
  match cp {
    0x20a9 | 0x1b132 | 0x1b155 | 0x1f200 | 0x1f202 | 0x1f237 | 0x1f23b => true
    _ =>
      // Range checks
      cjk_in_ranges(cp)
  }
}

///|
fn cjk_in_ranges(cp : Int) -> Bool {
  cjk_in_range(cp, 0x2329, 0x232a) ||
  cjk_in_range(cp, 0x2630, 0x2637) ||
  cjk_in_range(cp, 0x268a, 0x268f) ||
  cjk_in_range(cp, 0x2e80, 0x2e99) ||
  cjk_in_range(cp, 0x2e9b, 0x2ef3) ||
  cjk_in_range(cp, 0x2f00, 0x2fd5) ||
  cjk_in_range(cp, 0x2ff0, 0x303e) ||
  cjk_in_range(cp, 0x3041, 0x3096) ||
  cjk_in_range(cp, 0x3099, 0x30ff) ||
  cjk_in_range(cp, 0x3105, 0x312f) ||
  cjk_in_range(cp, 0x3131, 0x318e) ||
  cjk_in_range(cp, 0x3190, 0x31e5) ||
  cjk_in_range(cp, 0x31ef, 0x321e) ||
  cjk_in_range(cp, 0x3220, 0x3247) ||
  cjk_in_range(cp, 0x3250, 0xa48c) ||
  cjk_in_range(cp, 0xa490, 0xa4c6) ||
  cjk_in_range(cp, 0xa960, 0xa97c) ||
  cjk_in_range(cp, 0xac00, 0xd7a3) ||
  cjk_in_range(cp, 0xd7b0, 0xd7c6) ||
  cjk_in_range(cp, 0xd7cb, 0xd7fb) ||
  cjk_in_range(cp, 0xf900, 0xfaff) ||
  cjk_in_range(cp, 0xfe10, 0xfe19) ||
  cjk_in_range(cp, 0xfe30, 0xfe52) ||
  cjk_in_range(cp, 0xfe54, 0xfe66) ||
  cjk_in_range(cp, 0xfe68, 0xfe6b) ||
  cjk_in_range(cp, 0xff01, 0xffbe) ||
  cjk_in_range(cp, 0xffc2, 0xffc7) ||
  cjk_in_range(cp, 0xffca, 0xffcf) ||
  cjk_in_range(cp, 0xffd2, 0xffd7) ||
  cjk_in_range(cp, 0xffda, 0xffdc) ||
  cjk_in_range(cp, 0xffe0, 0xffe6) ||
  cjk_in_range(cp, 0xffe8, 0xffee) ||
  cjk_in_range(cp, 0x16fe0, 0x16fe4) ||
  cjk_in_range(cp, 0x16ff0, 0x16ff6) ||
  cjk_in_range(cp, 0x17000, 0x18cd5) ||
  cjk_in_range(cp, 0x18cff, 0x18d1e) ||
  cjk_in_range(cp, 0x18d80, 0x18df2) ||
  cjk_in_range(cp, 0x1aff0, 0x1aff3) ||
  cjk_in_range(cp, 0x1aff5, 0x1affb) ||
  cjk_in_range(cp, 0x1affd, 0x1affe) ||
  cjk_in_range(cp, 0x1b000, 0x1b122) ||
  cjk_in_range(cp, 0x1b150, 0x1b152) ||
  cjk_in_range(cp, 0x1b164, 0x1b167) ||
  cjk_in_range(cp, 0x1b170, 0x1b2fb) ||
  cjk_in_range(cp, 0x1d300, 0x1d356) ||
  cjk_in_range(cp, 0x1d360, 0x1d376) ||
  cjk_in_range(cp, 0x1f210, 0x1f219) ||
  cjk_in_range(cp, 0x1f21b, 0x1f22e) ||
  cjk_in_range(cp, 0x1f230, 0x1f231) ||
  cjk_in_range(cp, 0x1f240, 0x1f248) ||
  cjk_in_range(cp, 0x1f260, 0x1f265) ||
  cjk_in_range(cp, 0x20000, 0x3fffd)
}

///|
fn cjk_in_range(cp : Int, lo : Int, hi : Int) -> Bool {
  cp >= lo && cp <= hi
}

///|
priv struct CjkFriendlySequence {
  is_cjk : Bool
  is_ideographic_variation_selector : Bool
  is_punctuation : Bool
}

///|
fn classify_preceding_cjk_friendly_sequence(
  prev : Char,
  get_prev_prev : () -> Char?,
) -> CjkFriendlySequence {
  guard prev.is_non_emoji_general_variation_selector() else {
    return {
      is_cjk: prev.is_cjk_character(),
      is_ideographic_variation_selector: prev.is_ideographic_variation_selector(),
      is_punctuation: is_punctuation(prev.to_int()),
    }
  }
  guard get_prev_prev() is Some(base_char) else {
    return {
      is_cjk: false,
      is_ideographic_variation_selector: false,
      is_punctuation: false,
    }
  }
  {
    is_cjk: base_char.is_cjk_character() ||
    is_cjk_ambiguous_punctuation_sequence(base_char, prev),
    is_ideographic_variation_selector: false,
    is_punctuation: is_punctuation(base_char.to_int()),
  }
}

///|
fn is_preceding_cjk_friendly_punctuation(
  prev : Char,
  get_prev_prev : () -> Char?,
) -> Bool {
  guard prev.is_non_emoji_general_variation_selector() else {
    return is_punctuation(prev.to_int())
  }
  get_prev_prev().map_or(false, base => is_punctuation(base.to_int()))
}

///|
fn is_cjk_ambiguous_punctuation_sequence(ch : Char, vs : Char) -> Bool {
  vs.to_int() == 0xFE01 &&
  (
    ch.to_int() == 0x2018 ||
    ch.to_int() == 0x2019 ||
    ch.to_int() == 0x201C ||
    ch.to_int() == 0x201D
  )
}

///|
fn Char::is_non_emoji_general_variation_selector(self : Char) -> Bool {
  let cp = self.to_int()
  cp >= 0xFE00 && cp <= 0xFE0E
}

///|
fn Char::is_ideographic_variation_selector(self : Char) -> Bool {
  let cp = self.to_int()
  cp >= 0xE0100 && cp <= 0xE01EF
}
