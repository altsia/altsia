///|
/// A symbolic variable. The key is the canonical TeX spelling of the symbol
/// as it appears in the parsed AST, e.g. `"x"` or `"\\alpha"`.
pub(all) struct SymbolKey {
  text : String
} derive(Eq, Compare, Debug)

///|
pub fn SymbolKey::make(text : String) -> SymbolKey {
  SymbolKey::{ text, }
}

///|
fn join_parts(name : String, children : Array[EvalExpr]) -> String {
  let inner : Array[String] = []
  for child in children {
    inner.push(child.to_canonical_string())
  }
  "\{name}(\{inner.join(", ")})"
}
