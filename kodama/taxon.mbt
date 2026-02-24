// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
pub(all) struct Taxon {
  numbering : String?
  text : String
}

///|
pub const DEFAULT_TAXON_SUFFIX : String = "."

///|
pub fn Taxon::display(self : Taxon) -> String {
  let text = Taxon::text_transform(self.text)
  guard self.numbering is Some(numbering) else { Taxon::with_suffix(text) }
  Taxon::with_suffix(text + numbering)
}

///|
pub fn Taxon::with_suffix(
  s : String,
  suffix? : String = DEFAULT_TAXON_SUFFIX,
) -> String {
  "\{s}\{suffix} "
}

///|
pub fn Taxon::text_transform(text : String) -> String {
  guard text.get_char(0) is Some(first_char) else { text }
  let first_upper = to_uppercase(first_char)
  let rest_start = first_char.utf16_len()
  let rest = text.unsafe_substring(start=rest_start, end=text.length())
  first_upper + rest
}

///|
pub fn to_uppercase(ch : Char) -> String {
  let code = ch.to_int()
  let upper_code = if code >= 'a' && code <= 'z' {
    Some(code - 32)
  } else if (code >= 0x00E0 && code <= 0x00F6) ||
    (code >= 0x00F8 && code <= 0x00FE) {
    // Latin-1 supplement lowercase ranges with delta -32 mapping.
    Some(code - 32)
  } else if code == 0x00FF {
    // `ÿ` -> `Ÿ`
    Some(0x0178)
  } else if code >= 0x03B1 && code <= 0x03C1 {
    // Greek lowercase `α..ρ` -> `Α..Ρ`
    Some(code - 32)
  } else if code == 0x03C2 {
    // Greek final sigma `ς` -> `Σ`
    Some(0x03A3)
  } else if code >= 0x03C3 && code <= 0x03CB {
    // Greek lowercase `σ..ϋ` -> `Σ..Ϋ`
    Some(code - 32)
  } else if code >= 0x0430 && code <= 0x044F {
    // Cyrillic lowercase `а..я` -> `А..Я`
    Some(code - 32)
  } else {
    None
  }
  match upper_code {
    Some(mapped) => mapped.unsafe_to_char().to_string()
    None => ch.to_string()
  }
}
