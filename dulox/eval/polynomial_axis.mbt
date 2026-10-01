///|
/// A polynomial axis: a symbolic variable, or an opaque expression that can
/// participate in symbolic arithmetic as an indivisible factor.
pub(all) enum MonomialFactor {
  SymbolFactor(SymbolKey)
  OpaqueFactor(EvalExpr)
} derive(Eq, Debug)

///|
fn MonomialFactor::to_canonical_string(self : MonomialFactor) -> String {
  match self {
    SymbolFactor(symbol) => "s\{symbol.text}"
    OpaqueFactor(expr) => "o\{expr.to_canonical_string()}"
  }
}

///|
fn compare_canonical_strings(left : String, right : String) -> Int {
  let left_length = left.length()
  let right_length = right.length()
  let mut i = 0
  while i < left_length && i < right_length {
    let left_char = left[i]
    let right_char = right[i]
    if left_char != right_char {
      return if left_char < right_char { -1 } else { 1 }
    }
    i = i + 1
  }
  if left_length != right_length {
    return if left_length < right_length { -1 } else { 1 }
  }
  0
}
