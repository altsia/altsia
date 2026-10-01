using @rational { type BigRational }

///|
/// A computed mathematical expression. Canonicalized by `normalize`:
/// addition/multiplication are flattened, like terms are combined, and
/// children are sorted by total degree. Numbers are exact `Int` values.
pub(all) enum EvalExpr {
  Integer(Int)
  Rational(BigRational)
  Symbol(SymbolKey)
  Add(Array[EvalExpr])
  Mul(Array[EvalExpr])
  IntPow(EvalExpr, Int)
  Pow(EvalExpr, EvalExpr)
  Div(EvalExpr, EvalExpr)
  Root(index~ : EvalExpr, EvalExpr)
  RootOfUnity(order~ : EvalExpr, power~ : EvalExpr)
  Complex(EvalExpr, EvalExpr)
  Residual(@katex.ParseNode)
} derive(Eq, Debug)

///|
pub let neg_one : EvalExpr = Integer(-1)

///|
pub let zero : EvalExpr = Integer(0)

///|
pub let one : EvalExpr = Integer(1)

///|
pub let two : EvalExpr = Integer(2)

///|
pub let three : EvalExpr = Integer(3)

///|
pub let sqrt : (EvalExpr) -> EvalExpr = expr => Root(index=two, expr)

///|
pub let cbrt : (EvalExpr) -> EvalExpr = expr => Root(index=three, expr)

///|
fn complex(re : EvalExpr, im : EvalExpr) -> EvalExpr {
  guard im != zero else { re }
  Complex(re, im)
}

///|
impl Neg for EvalExpr with fn neg(expr : EvalExpr) {
  Mul([neg_one, expr])
}

///|
impl Add for EvalExpr with fn add(a : EvalExpr, b : EvalExpr) -> EvalExpr {
  Add([a, b])
}

///|
impl Sub for EvalExpr with fn sub(a : EvalExpr, b : EvalExpr) -> EvalExpr {
  Add([a, -b])
}

///|
impl Mul for EvalExpr with fn mul(a : EvalExpr, b : EvalExpr) -> EvalExpr {
  Mul([a, b])
}

///|
impl Div for EvalExpr with fn div(a : EvalExpr, b : EvalExpr) -> EvalExpr {
  Div(a, b)
}

///|
/// Canonical serialization of an expression, used for structured test
/// assertions and s a stable key for opaque terms. Two structurally equal
/// expressions produce equal strings.
pub fn EvalExpr::to_canonical_string(self : EvalExpr) -> String {
  match self {
    Integer(value) => "N\{value}"
    Rational(value) =>
      "Q(\{value.numerator().to_string()}/\{value.denominator().to_string()})"
    Symbol(symbol) => "S\{symbol.text}"
    Add(children) => join_parts("A", children)
    Mul(children) => join_parts("M", children)
    IntPow(base, exp) => "P(\{base.to_canonical_string()}, \{exp})"
    Pow(base, exp) =>
      "G(\{base.to_canonical_string()}, \{exp.to_canonical_string()})"
    Div(numer, denom) =>
      "D(\{numer.to_canonical_string()}, \{denom.to_canonical_string()})"
    Root(index~, radicand) =>
      "R(\{index.to_canonical_string()}, \{radicand.to_canonical_string()})"
    RootOfUnity(order~, power~) =>
      "U(\{order.to_canonical_string()}, \{power.to_canonical_string()})"
    Complex(re, im) =>
      "C(\{re.to_canonical_string()}, \{im.to_canonical_string()})"
    Residual(node) => "R\{@debug.to_string(node)}"
  }
}
