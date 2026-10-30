///|
/// The first/last character of an inline run, for neighbor-aware half-width
/// conversion: text nodes contribute their boundary character, nested
/// inline containers recurse, and other nodes contribute nothing.
fn inline_first_char(inline : @document.Node) -> Char? {
  match inline {
    Text(text) => text.iter().next()
    Strong(inlines) | Emph(inlines) | InlineRun(inlines) =>
      array_first_char(inlines)
    Element(element) if inline.is_inline() =>
      array_first_char(element.content)
    _ => None
  }
}

///|
fn array_first_char(inlines : Array[@document.Node]) -> Char? {
  inlines.filter_map(inline_first_char).get(0)
}

///|
fn inline_last_char(inline : @document.Node) -> Char? {
  match inline {
    Text(text) => text.iter().last()
    Strong(inlines) | Emph(inlines) | InlineRun(inlines) =>
      array_last_char(inlines)
    Element(element) if inline.is_inline() =>
      array_last_char(element.content)
    _ => None
  }
}

///|
fn array_last_char(inlines : Array[@document.Node]) -> Char? {
  inlines.filter_map(inline_last_char).last()
}

///|
/// The boundary characters around the inline at index `i`: the last
/// character of the preceding inline (or `prev` when `i` is first) and the
/// first character of the following inline (or `next` when `i` is last).
fn inline_neighbors(
  inlines : Array[@document.Node],
  i : Int32,
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
