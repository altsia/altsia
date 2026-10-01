///|
fn lower_ordinary_node(
  node : @katex.ParseNode,
  text : String,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  if is_all_digits(text) {
    match parse_decimal_int(text) {
      None => raise EvalDiagnostic::make(InvalidNumber)
      Some(value) => Integer(value)
    }
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
  match (base, subscript, superscript) {
    (Some(base), None, Some(exponent)) =>
      lower_power(lower_node(base, options), lower_node(exponent, options))
    _ => unsupported(original, options)
  }
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
  match index {
    None => Root(index=two, radicand)
    Some(index) => {
      let index = lower_node(index, options)
      guard !(index is Integer(value) && value <= 0) else {
        raise EvalDiagnostic::make(InvalidPower)
      }
      Root(index~, radicand)
    }
  }
}
