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
  for i = 0; i < left_length && i < right_length; i = i + 1 {
    let left_char = left[i]
    let right_char = right[i]
    guard left_char == right_char else {
      return if left_char < right_char { -1 } else { 1 }
    }
  }
  guard left_length == right_length else {
    return if left_length < right_length { -1 } else { 1 }
  }
  0
}
