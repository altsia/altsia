///|
fn normalize_poly_one() -> Polynomial[Int] {
  Polynomial::one([])
}

///|
fn normalize_poly_from_expr(
  expr : EvalExpr,
  max_terms : Int,
) -> Polynomial[Int] raise EvalDiagnostic {
  match expr {
    Integer(value) => Polynomial::from_constant([], value)
    Symbol(symbol) => algebra_from_factor_term([SymbolFactor(symbol)], [1], 1)
    IntPow(Symbol(symbol), exponent) =>
      algebra_from_factor_term([SymbolFactor(symbol)], [exponent], 1)
    Add(children) => {
      let mut result = Polynomial::zero([])
      for child in children {
        result = normalize_add_polynomials(
          result,
          normalize_poly_from_expr(child, max_terms),
          max_terms,
        )
      }
      result
    }
    Mul(children) => {
      let mut result = normalize_poly_one()
      for child in children {
        result = normalize_mul_polynomials(
          result,
          normalize_poly_from_expr(child, max_terms),
          max_terms,
        )
      }
      result
    }
    IntPow(_, _)
    | Pow(_, _)
    | Rational(_)
    | Div(_, _)
    | Root(_)
    | RootOfUnity(_)
    | Complex(_, _)
    | Residual(_) => normalize_opaque_term(expr)
  }
}

///|
fn normalize_opaque_term(expr : EvalExpr) -> Polynomial[Int] {
  algebra_from_factor_term([OpaqueFactor(expr)], [1], 1)
}

///|
fn normalize_add_polynomials(
  a : Polynomial[Int],
  b : Polynomial[Int],
  max_terms : Int,
) -> Polynomial[Int] raise EvalDiagnostic {
  let (a, b) = algebra_align(a, b)
  let builder = NormalizePolynomialBuilder::make(a.axes, max_terms)
  builder.add_all(a.terms)
  builder.add_all(b.terms)
  builder.finish()
}

///|
fn normalize_mul_polynomials(
  a : Polynomial[Int],
  b : Polynomial[Int],
  max_terms : Int,
) -> Polynomial[Int] raise EvalDiagnostic {
  let (a, b) = algebra_align(a, b)
  let builder = NormalizePolynomialBuilder::make(a.axes, max_terms)
  for _, left in a.terms {
    for _, right in b.terms {
      guard checked_int_mul(left.coeff, right.coeff) is Some(coeff) else {
        raise EvalDiagnostic::make(IntegerOverflow)
      }
      builder.add({ exps: algebra_add_exponents(left.exps, right.exps), coeff, })
    }
  }
  builder.finish()
}

///|
fn normalize_pow_polynomial(
  base : Polynomial[Int],
  exponent : Int,
  max_terms : Int,
) -> Polynomial[Int] raise EvalDiagnostic {
  guard exponent >= 0 else { raise EvalDiagnostic::make(InvalidPower) }
  let mut result = normalize_poly_one()
  let mut factor = base
  let mut remaining = exponent
  while remaining > 0 {
    if remaining % 2 == 1 {
      result = normalize_mul_polynomials(result, factor, max_terms)
    }
    remaining = remaining / 2
    if remaining > 0 {
      factor = normalize_mul_polynomials(factor, factor, max_terms)
    }
  }
  result
}

///|
fn normalize_divide_polynomial(
  polynomial : Polynomial[Int],
  divisor : Int,
) -> Polynomial[Int]? {
  let terms = @hashmap.HashMap([])
  for _, term in polynomial.terms {
    guard term.coeff % divisor == 0 else { return None }
    let coeff = term.coeff / divisor
    if coeff != 0 {
      let key = algebra_monomial_key(term.exps)
      terms[key] = { exps: term.exps, coeff, }
    }
  }
  Some(Polynomial::{ axes: polynomial.axes, terms, })
}

///|
priv struct NormalizePolynomialBuilder {
  axes : Array[MonomialFactor]
  terms : @hashmap.HashMap[String, Term[Int]]
  max_terms : Int
}

///|
fn NormalizePolynomialBuilder::make(
  axes : Array[MonomialFactor],
  max_terms : Int,
) -> NormalizePolynomialBuilder {
  { axes, terms: @hashmap.HashMap([]), max_terms, }
}

///|
fn NormalizePolynomialBuilder::add(
  self : NormalizePolynomialBuilder,
  term : Term[Int],
) -> Unit raise EvalDiagnostic {
  guard term.coeff != 0 else { return }
  let key = algebra_monomial_key(term.exps)
  guard self.terms.get(key) is Some(existing) else {
    self.terms[key] = term
    guard self.terms.length() <= self.max_terms else {
      raise EvalDiagnostic::make(ExpressionTooLarge)
    }
    return
  }
  guard checked_int_add(existing.coeff, term.coeff) is Some(coeff) else {
    raise EvalDiagnostic::make(IntegerOverflow)
  }
  if coeff == 0 {
    self.terms.remove(key)
  } else {
    self.terms[key] = { exps: existing.exps, coeff, }
  }
}

///|
fn NormalizePolynomialBuilder::add_all(
  self : NormalizePolynomialBuilder,
  terms : @hashmap.HashMap[String, Term[Int]],
) -> Unit raise EvalDiagnostic {
  for _, term in terms {
    self.add(term)
  }
}

///|
fn NormalizePolynomialBuilder::finish(
  self : NormalizePolynomialBuilder,
) -> Polynomial[Int] {
  Polynomial::{ axes: self.axes, terms: self.terms, }
}
