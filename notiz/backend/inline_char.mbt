///|
/// The first/last character of an inline run, for neighbor-aware half-width
/// conversion: text nodes contribute their boundary character, nested
/// strong/emph recurse, and other inlines contribute nothing.
fn inline_first_char(inline : @parsing.Inline) -> Char? {
  match inline {
    Plain(text) => text.iter().next()
    Strong(inlines) => array_first_char(inlines)
    Emph(inlines) => array_first_char(inlines)
    _ => None
  }
}

///|
fn array_first_char(inlines : Array[@parsing.Inline]) -> Char? {
  inlines.filter_map(inline_first_char).get(0)
}

///|
fn inline_last_char(inline : @parsing.Inline) -> Char? {
  match inline {
    Plain(text) => text.iter().last()
    Strong(inlines) => array_last_char(inlines)
    Emph(inlines) => array_last_char(inlines)
    _ => None
  }
}

///|
fn array_last_char(inlines : Array[@parsing.Inline]) -> Char? {
  inlines.filter_map(inline_last_char).last()
}

///|
/// The boundary characters around the inline at index `i`: the last
/// character of the preceding inline (or `prev` when `i` is first) and the
/// first character of the following inline (or `next` when `i` is last).
fn inline_neighbors(
  inlines : Array[@parsing.Inline],
  i : Int,
  prev~ : Char?,
  next~ : Char?,
) -> (Char?, Char?) {
  let prev_c = if i > 0 { inline_last_char(inlines[i - 1]) } else { prev }
  let next_c = if i + 1 < inlines.length() {
    inline_first_char(inlines[i + 1])
  } else {
    next
  }
  (prev_c, next_c)
}
