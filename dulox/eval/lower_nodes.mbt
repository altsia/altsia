///|
fn lower_ordinary_node(
  node : @katex.ParseNode,
  text : String,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  if is_all_digits(text) {
    guard parse_decimal_int(text) is Some(value) else {
      raise EvalDiagnostic::make(InvalidNumber)
    }
    Integer(value)
  } else if text.length() == 1 || (text.length() > 1 && text[0] == '\\') {
    Symbol(SymbolKey::make(text))
  } else {
    unsupported(node, options)
  }
}

///|
fn lower_superscript(
  original : @katex.ParseNode,
  base : @katex.ParseNode?,
  subscript : @katex.ParseNode?,
  superscript : @katex.ParseNode?,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  guard (base, subscript, superscript) is (Some(base), None, Some(exponent)) else {
    return unsupported(original, options)
  }
  lower_power(lower_node(base, options), lower_node(exponent, options))
}

///|
fn lower_fraction(
  numerator : @katex.ParseNode,
  denominator : @katex.ParseNode,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  Div(lower_node(numerator, options), lower_node(denominator, options))
}

///|
fn lower_root(
  body : @katex.ParseNode,
  index : @katex.ParseNode?,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let radicand = lower_node(body, options)
  guard index is Some(index) else { return Root(index=two, radicand) }
  let index = lower_node(index, options)
  guard !(index is Integer(value) && value <= 0) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  Root(index~, radicand)
}
