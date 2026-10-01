///|
priv enum BinOp {
  Plus
  Minus
  Times
}

///|
priv enum LowerItem {
  ItemNumber(Int)
  ItemOp(BinOp)
  ItemExpr(EvalExpr)
}

///|
/// Lowers a flat list of parse nodes (e.g. the body of an `\eval` group) into
/// an expression tree, applying the implicit multiplication rules for
/// adjacent factors.
pub fn lower_expr(
  nodes : Array[@katex.ParseNode],
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let items = scan_items(nodes, options)
  let terms = split_terms(items)
  let exprs : Array[EvalExpr] = []
  for term in terms {
    let (term_items, neg) = term
    let expr = parse_factors(term_items)
    let expr = if neg { Mul([neg_one, expr]) } else { expr }
    exprs.push(expr)
  }
  match exprs.length() {
    0 => raise EvalDiagnostic::make(InvalidNumber)
    1 => exprs[0]
    _ => Add(exprs)
  }
}

///|
/// Lowers a single parse node. Only whitelisted node kinds are recognized;
/// everything else becomes a `Residual` (in partial mode) or an
/// `UnsupportedNode` diagnostic (in strict mode).
pub fn lower_node(
  node : @katex.ParseNode,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  match node {
    OrdGroup(body~, ..) => lower_expr(body, options)
    MathOrd(text~, ..) | TextOrd(text~, ..) =>
      lower_ordinary_node(node, text, options)
    SupSub(base~, sup~, sub~, ..) =>
      lower_superscript(node, base, sub, sup, options)
    GenFrac(numer~, denom~, ..) => lower_fraction(numer, denom, options)
    Sqrt(body~, index~, ..) => lower_root(body, index, options)
    _ => unsupported(node, options)
  }
}

///|
fn scan_items(
  nodes : Array[@katex.ParseNode],
  options : EvalOptions,
) -> Array[LowerItem] raise EvalDiagnostic {
  let items : Array[LowerItem] = []
  let mut cursor = 0
  while cursor < nodes.length() {
    cursor = scan_item_at(nodes, cursor, items, options)
  }
  items
}

///|
/// Lowers exactly one item and returns the cursor position after it.
fn scan_item_at(
  nodes : Array[@katex.ParseNode],
  cursor : Int,
  items : Array[LowerItem],
  options : EvalOptions,
) -> Int raise EvalDiagnostic {
  match nodes[cursor] {
    MathOrd(text~, ..) | TextOrd(text~, ..) if is_all_digits(text) =>
      append_number_item(nodes, cursor, items)
    Atom(family=Mbin, text~, ..) => {
      append_operator_item(items, nodes[cursor], text, options)
      cursor + 1
    }
    Atom(family=Mopen, text="(", ..) =>
      append_parenthesized_item(nodes, cursor, items, options)
    _ => {
      push_lowered(items, nodes[cursor], options)
      cursor + 1
    }
  }
}

///|
fn append_number_item(
  nodes : Array[@katex.ParseNode],
  start : Int,
  items : Array[LowerItem],
) -> Int raise EvalDiagnostic {
  match scan_number(nodes, start) {
    Err(error) => raise error
    Ok((value, next)) => {
      items.push(ItemNumber(value))
      next
    }
  }
}

///|
fn append_operator_item(
  items : Array[LowerItem],
  node : @katex.ParseNode,
  text : String,
  options : EvalOptions,
) -> Unit raise EvalDiagnostic {
  match text {
    "+" => items.push(ItemOp(Plus))
    "-" => items.push(ItemOp(Minus))
    "*" | "\\cdot" | "\\times" => items.push(ItemOp(Times))
    _ => push_lowered(items, node, options)
  }
}

///|
fn append_parenthesized_item(
  nodes : Array[@katex.ParseNode],
  start : Int,
  items : Array[LowerItem],
  options : EvalOptions,
) -> Int raise EvalDiagnostic {
  match scan_paren_end(nodes, start) {
    None => {
      push_lowered(items, nodes[start], options)
      start + 1
    }
    Some(end) => {
      items.push(
        ItemExpr(lower_parenthesized_group(nodes, start, end, options)),
      )
      parenthesized_group_next(end)
    }
  }
}

///|
fn lower_parenthesized_group(
  nodes : Array[@katex.ParseNode],
  start : Int,
  end : ParenEnd,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let (closing, exponent) = parenthesized_group_parts(end)
  let group = lower_expr(
    parenthesized_group_body(nodes, start, closing),
    options,
  )
  match exponent {
    None => group
    Some(node) => lower_power(group, lower_node(node, options))
  }
}

///|
fn parenthesized_group_body(
  nodes : Array[@katex.ParseNode],
  start : Int,
  closing : Int,
) -> Array[@katex.ParseNode] {
  let inner : Array[@katex.ParseNode] = []
  for index in (start + 1)..<closing {
    inner.push(nodes[index])
  }
  inner
}

///|
fn parenthesized_group_parts(end : ParenEnd) -> (Int, @katex.ParseNode?) {
  match end {
    ParenEndNoExp(closing) => (closing, None)
    ParenEndWithExp(closing, exponent) => (closing, Some(exponent))
  }
}

///|
fn parenthesized_group_next(end : ParenEnd) -> Int {
  match end {
    ParenEndNoExp(closing) | ParenEndWithExp(closing, _) => closing + 1
  }
}

///|
fn lower_power(base : EvalExpr, exponent : EvalExpr) -> EvalExpr {
  match exponent {
    Integer(value) => IntPow(base, value)
    _ => Pow(base, exponent)
  }
}

///|
fn push_lowered(
  items : Array[LowerItem],
  node : @katex.ParseNode,
  options : EvalOptions,
) -> Unit raise EvalDiagnostic {
  let expr = lower_node(node, options)
  items.push(ItemExpr(expr))
}

///|
/// Merges a run of digit `MathOrd`/`TextOrd` nodes into an exact integer. A
/// decimal point in the run is rejected (`InvalidNumber`): rational/decimal
/// arithmetic is not supported yet.
fn scan_number(
  nodes : Array[@katex.ParseNode],
  start : Int,
) -> Result[(Int, Int), EvalDiagnostic] {
  let first_text = match nodes[start] {
    MathOrd(text~, ..) | TextOrd(text~, ..) => text
    _ => return Err(EvalDiagnostic::make(InvalidNumber))
  }
  let mut acc = first_text
  let mut j = start + 1
  while j < nodes.length() {
    match nodes[j] {
      MathOrd(text~, ..) | TextOrd(text~, ..) if is_all_digits(text) => {
        acc = acc + text
        j = j + 1
      }
      MathOrd(text~, ..) | TextOrd(text~, ..) if text == "." =>
        return Err(
          EvalDiagnostic::make(InvalidNumber, loc=node_loc(nodes[start])),
        )
      Atom(family=Mpunct, text~, ..) if text == "." =>
        return Err(
          EvalDiagnostic::make(InvalidNumber, loc=node_loc(nodes[start])),
        )
      _ => break
    }
  }
  match parse_decimal_int(acc) {
    None => Err(EvalDiagnostic::make(InvalidNumber, loc=node_loc(nodes[start])))
    Some(value) => Ok((value, j))
  }
}

///|
/// Parses digit text into an `Int`, rejecting overflow.
fn parse_decimal_int(text : String) -> Int? {
  let mut value = 0
  for c in text {
    let digit = c.to_int() - '0'.to_int()
    if value > (2147483647 - digit) / 10 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
/// Splits the item stream into terms at binary `+`/`-`; unary signs stay in
/// the term and are handled at factor level. Returns `(term items, negated)`.
fn split_terms(items : Array[LowerItem]) -> Array[(Array[LowerItem], Bool)] {
  let terms : Array[(Array[LowerItem], Bool)] = []
  let mut current : Array[LowerItem] = []
  let mut negated = false
  for index in 0..<items.length() {
    let item = items[index]
    if is_term_separator(item, index, items) {
      terms.push((current, negated))
      current = []
      negated = separator_negates_next_term(item)
    } else {
      current.push(item)
    }
  }
  terms.push((current, negated))
  terms
}

///|
fn is_term_separator(
  item : LowerItem,
  index : Int,
  items : Array[LowerItem],
) -> Bool {
  match item {
    ItemOp(Plus) => true
    ItemOp(Minus) => index > 0 && is_value_item(items[index - 1])
    _ => false
  }
}

///|
fn separator_negates_next_term(item : LowerItem) -> Bool {
  match item {
    ItemOp(Minus) => true
    _ => false
  }
}

///|
fn is_value_item(item : LowerItem) -> Bool {
  match item {
    ItemNumber(_) | ItemExpr(_) => true
    ItemOp(_) => false
  }
}

///|
/// Builds a factor list from a term's items: `*` separates factors, adjacent
/// value items multiply implicitly, and unary `-` negates the next factor.
fn parse_factors(items : Array[LowerItem]) -> EvalExpr raise EvalDiagnostic {
  let factors : Array[EvalExpr] = []
  let mut i = 0
  while i < items.length() {
    match items[i] {
      ItemOp(Times) | ItemOp(Plus) => i = i + 1
      ItemOp(Minus) => {
        guard i + 1 < items.length() else {
          raise EvalDiagnostic::make(InvalidNumber)
        }
        i = i + 1
        match items[i] {
          ItemNumber(value) => {
            factors.push(Integer(value.neg()))
            i = i + 1
          }
          ItemExpr(expr) => {
            factors.push(Mul([neg_one, expr]))
            i = i + 1
          }
          _ => raise EvalDiagnostic::make(InvalidNumber)
        }
      }
      ItemNumber(value) => {
        factors.push(Integer(value))
        i = i + 1
      }
      ItemExpr(expr) => {
        factors.push(expr)
        i = i + 1
      }
    }
  }
  match factors.length() {
    0 => raise EvalDiagnostic::make(InvalidNumber)
    1 => factors[0]
    _ => Mul(factors)
  }
}

///|
priv enum ParenEnd {
  /// The group is closed by a standalone `)` atom at the given index.
  ParenEndNoExp(Int)
  /// The group is closed by a superscripted `)` atom (`(x+1)^2` parses as
  /// `SupSub(base=Atom(")"), sup=...)`); the node carries the exponent.
  ParenEndWithExp(Int, @katex.ParseNode)
}

///|
/// Returns the node that closes the paren group opened at `start`, counting
/// nested parens; `None` when unbalanced.
fn scan_paren_end(nodes : Array[@katex.ParseNode], start : Int) -> ParenEnd? {
  let mut depth = 0
  let mut j = start
  while j < nodes.length() {
    match nodes[j] {
      Atom(family=Mopen, text="(", ..) => depth = depth + 1
      Atom(family=Mclose, text=")", ..) => {
        depth = depth - 1
        if depth == 0 {
          return Some(ParenEndNoExp(j))
        }
      }
      SupSub(
        base=Some(Atom(family=Mclose, text=")", ..)),
        sup=Some(exponent),
        sub=None,
        ..
      ) if depth == 1 => return Some(ParenEndWithExp(j, exponent))
      _ => ()
    }
    j = j + 1
  }
  None
}

///|
fn unsupported(
  node : @katex.ParseNode,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  unsupported_with(node, options, UnsupportedNode)
}

///|
fn unsupported_with(
  node : @katex.ParseNode,
  options : EvalOptions,
  kind : EvalFailureKind,
) -> EvalExpr raise EvalDiagnostic {
  match options.mode {
    Strict => raise EvalDiagnostic::make(kind, loc=node_loc(node))
    Partial => Residual(node)
  }
}

///|
fn is_all_digits(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for c in text {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn node_loc(node : @katex.ParseNode) -> @katex.SourceLocation? {
  match node {
    OrdGroup(loc~, ..) => loc
    MathOrd(loc~, ..) => loc
    TextOrd(loc~, ..) => loc
    Atom(loc~, ..) => loc
    _ => None
  }
}
