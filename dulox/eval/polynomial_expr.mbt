///|
fn[E] Term::degree(self : Term[E]) -> Int {
  let mut total = 0
  for exp in self.exps {
    total = total + exp
  }
  total
}

///|
fn[E] algebra_term_to_canonical_string(
  term : Term[E],
  axes : Array[MonomialFactor],
) -> String {
  let parts : Array[String] = []
  for i in 0..<term.exps.length() {
    let exp = term.exps[i]
    if exp != 0 {
      parts.push("\{axes[i].to_canonical_string()}^\{exp}")
    }
  }
  parts.join("|")
}

///|
fn[E] algebra_term_compare(
  left : Term[E],
  right : Term[E],
  axes : Array[MonomialFactor],
) -> Int {
  let left_degree = left.degree()
  let right_degree = right.degree()
  if left_degree != right_degree {
    return if left_degree > right_degree { -1 } else { 1 }
  }
  compare_canonical_strings(
    algebra_term_to_canonical_string(left, axes),
    algebra_term_to_canonical_string(right, axes),
  )
}

///|
fn[E] algebra_sorted_terms(poly : Polynomial[E]) -> Array[Term[E]] {
  let terms : Array[Term[E]] = []
  for _, term in poly.terms {
    terms.push(term)
  }
  terms.sort_by((left, right) => algebra_term_compare(left, right, poly.axes))
  terms
}

///|
/// Converts an integer polynomial expression into the sparse representation.
/// Non-polynomial nodes are rejected instead of being made opaque axes.
pub fn expr_to_polynomial(
  expr : EvalExpr,
) -> Polynomial[Int] raise EvalDiagnostic {
  match expr {
    Integer(value) => Polynomial::from_constant([], value)
    Symbol(symbol) => algebra_from_factor_term([SymbolFactor(symbol)], [1], 1)
    Add(children) => {
      let mut result = Polynomial::zero([])
      for child in children {
        result = result + expr_to_polynomial(child)
      }
      result
    }
    Mul(children) => {
      let mut result = Polynomial::one([])
      for child in children {
        result = result * expr_to_polynomial(child)
      }
      result
    }
    IntPow(base, exp) => {
      guard exp >= 0 else { raise EvalDiagnostic::make(NotPolynomial) }
      expr_to_polynomial(base).pow(exp)
    }
    Rational(_)
    | Pow(_, _)
    | Div(_, _)
    | Root(_)
    | RootOfUnity(_)
    | Complex(_, _)
    | Residual(_) => raise EvalDiagnostic::make(NotPolynomial)
  }
}

///|
fn algebra_factor_to_expr(factor : MonomialFactor) -> EvalExpr {
  match factor {
    SymbolFactor(symbol) => Symbol(symbol)
    OpaqueFactor(expr) => expr
  }
}

///|
fn algebra_term_to_expr(
  term : Term[Int],
  axes : Array[MonomialFactor],
) -> EvalExpr {
  let factors : Array[EvalExpr] = []
  for i in 0..<axes.length() {
    let exp = term.exps[i]
    if exp != 0 {
      let factor = algebra_factor_to_expr(axes[i])
      factors.push(if exp == 1 { factor } else { IntPow(factor, exp) })
    }
  }
  if factors.length() == 0 {
    Integer(term.coeff)
  } else if term.coeff == 1 {
    match factors.length() {
      1 => factors[0]
      _ => Mul(factors)
    }
  } else {
    Mul([Integer(term.coeff), ..factors])
  }
}

///|
/// Converts an integer sparse polynomial back into an evaluator expression in
/// graded lexicographic order.
pub fn Polynomial::to_expr(poly : Polynomial[Int]) -> EvalExpr {
  let terms = algebra_sorted_terms(poly)
  match terms.length() {
    0 => zero
    1 => algebra_term_to_expr(terms[0], poly.axes)
    _ => Add(terms.map(term => algebra_term_to_expr(term, poly.axes)))
  }
}
