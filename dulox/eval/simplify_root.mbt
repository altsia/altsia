///|
/// Dispatches root simplification after validating the root index.
fn simplify_root(
  index : EvalExpr,
  radicand : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  guard !(index is Integer(value) && value <= 0) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  match index {
    Integer(1) => radicand
    Integer(2) => radicand.simplify_square_root(domain)
    Integer(n) if n > 2 => radicand.simplify_integer_root(n, domain)
    _ => Root(index~, radicand)
  }
}

///|
/// Applies the special principal-square-root rules before delegating to the
/// general integer-root helpers.
fn EvalExpr::simplify_square_root(
  inner : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match inner {
    Root(index=Integer(inner_index), radicand) if inner_index > 0 =>
      simplify_nested_root(2, inner_index, radicand, inner, domain)
    Mul(children) => simplify_integer_root_product(children, 2)
    Integer(0) => zero
    Integer(1) => one
    Integer(n) if n > 0 => simplify_positive_integer_root(2, n)
    Integer(n) => simplify_negative_square_root(n, domain)
    Rational(value) => simplify_rational_square_root(value, inner, domain)
    Div(Integer(numer), Integer(denom)) if denom != 0 =>
      simplify_integer_division_square_root(numer, denom, inner, domain)
    _ => Root(index=two, inner)
  }
}

///|
fn simplify_negative_square_root(
  value : Int,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match domain {
    C => Complex(zero, Integer(-value).simplify_square_root(domain))
    R => Root(index=two, Integer(value))
  }
}

///|
fn simplify_rational_square_root(
  value : @rational.BigRational,
  original : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  if bigint_to_int(value.numerator()) is Some(numerator) &&
    bigint_to_int(value.denominator()) is Some(denominator) {
    simplify_rational_integer_root(2, numerator, denominator, domain)
  } else {
    Root(index=two, original)
  }
}

///|
fn simplify_integer_division_square_root(
  numer : Int,
  denom : Int,
  original : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  if numer < 0 {
    return match domain {
      C =>
        Complex(
          zero,
          Div(Integer(-numer), Integer(denom)).simplify_square_root(domain),
        )
      R => Root(index=two, original)
    }
  }
  rebuild_square_root_quotient(
    Integer(numer).simplify_square_root(domain),
    Integer(denom).simplify_square_root(domain),
  )
}

///|
fn rebuild_square_root_quotient(numer : EvalExpr, denom : EvalExpr) -> EvalExpr {
  match (numer, denom) {
    (Integer(a), Integer(b)) => rational_to_expr(exact_rational_from_pair(a, b))
    (n, d) => Div(n, d)
  }
}

///|
/// Applies integer-root rules that are shared by square roots and higher roots.
fn EvalExpr::simplify_integer_root(
  inner : EvalExpr,
  index : Int,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match inner {
    Integer(0) => zero
    Integer(1) => one
    Integer(n) if n > 1 => simplify_positive_integer_root(index, n)
    Integer(n) if index % 2 == 1 =>
      simplify_mul([neg_one, simplify_positive_integer_root(index, -n)])
    Div(Integer(numer), Integer(denom)) if denom != 0 =>
      simplify_rational_integer_root(index, numer, denom, domain)
    Rational(value) => simplify_rational_value_root(index, value, inner, domain)
    Root(index=Integer(inner_index), radicand) if inner_index > 0 =>
      simplify_nested_root(index, inner_index, radicand, inner, domain)
    Mul(children) => simplify_integer_root_product(children, index)
    _ => Root(index=Integer(index), inner)
  }
}

///|
fn simplify_rational_value_root(
  index : Int,
  value : @rational.BigRational,
  original : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  if bigint_to_int(value.numerator()) is Some(numerator) &&
    bigint_to_int(value.denominator()) is Some(denominator) {
    simplify_rational_integer_root(index, numerator, denominator, domain)
  } else {
    Root(index=Integer(index), original)
  }
}

///|
fn simplify_nested_root(
  outer_index : Int,
  inner_index : Int,
  radicand : EvalExpr,
  original : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match checked_int_mul(outer_index, inner_index) {
    Some(combined_index) =>
      simplify_root(Integer(combined_index), radicand, domain)
    None => Root(index=Integer(outer_index), original)
  }
}

///|
/// Extracts a positive exact nth-power coefficient from a product. This is
/// valid for principal roots because multiplying the radicand by a positive
/// real nth power scales its principal root by the corresponding positive
/// real factor. No root-of-a-product rule is applied to arbitrary factors.
fn simplify_integer_root_product(
  children : Array[EvalExpr],
  index : Int,
) -> EvalExpr raise EvalDiagnostic {
  let factors = flatten_mul(children)
  let (coefficient, rest) = collect_positive_integer_factors(factors)
  match extract_root_coefficient(coefficient, index) {
    None => Root(index=Integer(index), Mul(factors))
    Some((extracted, remainder)) =>
      simplify_mul([
        Integer(extracted),
        Root(index=Integer(index), rebuild_extracted_radicand(remainder, rest)),
      ])
  }
}

///|
fn extract_root_coefficient(coefficient : Int, index : Int) -> (Int, Int)? {
  let extracted = nth_root_factor(coefficient, index)
  guard extracted > 1 else { None }
  guard checked_pow(extracted, index) is Some(power) else { None }
  Some((extracted, coefficient / power))
}

///|
fn collect_positive_integer_factors(
  factors : Array[EvalExpr],
) -> (Int, Array[EvalExpr]) {
  let mut coefficient = 1
  let rest : Array[EvalExpr] = []
  for factor in factors {
    match factor {
      Integer(value) if value > 0 =>
        match checked_int_mul(coefficient, value) {
          Some(product) => coefficient = product
          None => rest.push(factor)
        }
      _ => rest.push(factor)
    }
  }
  (coefficient, rest)
}

///|
fn rebuild_extracted_radicand(
  coefficient : Int,
  rest : Array[EvalExpr],
) -> EvalExpr {
  let factors : Array[EvalExpr] = []
  if coefficient != 1 {
    factors.push(Integer(coefficient))
  }
  factors.append(rest)
  match factors.length() {
    0 => one
    1 => factors[0]
    _ => Mul(factors)
  }
}

///|
fn simplify_positive_integer_root(index : Int, radicand : Int) -> EvalExpr {
  guard perfect_nth_root(radicand, index) is Some(root) else {
    let factor = nth_root_factor(radicand, index)
    guard factor > 1 else { Root(index=Integer(index), Integer(radicand)) }
    guard checked_pow(factor, index) is Some(factor_power) else {
      Root(index=Integer(index), Integer(radicand))
    }
    return Mul([
      Integer(factor),
      Root(index=Integer(index), Integer(radicand / factor_power)),
    ])
  }
  Integer(root)
}

///|
fn simplify_rational_integer_root(
  index : Int,
  numer : Int,
  denom : Int,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  guard numer != 0 else { zero }
  guard numer > 0 || (domain is R && index % 2 == 1) else {
    Root(index=Integer(index), Div(Integer(numer), Integer(denom)))
  }
  if numer < 0 {
    return simplify_mul([
      neg_one,
      simplify_rational_integer_root(index, -numer, denom, domain),
    ])
  }
  rebuild_rational_root(
    simplify_positive_integer_root(index, numer),
    simplify_positive_integer_root(index, denom),
  )
}

///|
fn rebuild_rational_root(numer : EvalExpr, denom : EvalExpr) -> EvalExpr {
  match (numer, denom) {
    (Integer(a), Integer(b)) if b == 1 => Integer(a)
    (Integer(a), Integer(b)) => Div(Integer(a), Integer(b))
    (n, Integer(1)) => n
    (Integer(0), _) => zero
    (n, d) => Div(n, d)
  }
}
