///|
/// Normalizes an expression to canonical form using bounded fixed-point passes.
pub fn normalize(
  expr : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  rewrite_to_fixed_point(expr, options.max_rewrite_steps, current => {
    normalize_once(current, options)
  })
}

///|
fn rewrite_to_fixed_point(
  expr : EvalExpr,
  max_steps : Int,
  rewrite : (EvalExpr) -> EvalExpr raise EvalDiagnostic,
) -> EvalExpr raise EvalDiagnostic {
  let mut current = expr
  for _ in 0..<max_steps {
    let next = rewrite(current)
    guard next != current else { return current }
    current = next
  }
  raise EvalDiagnostic::make(TooManyRewriteSteps)
}

///|
fn normalize_once(
  expr : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  match expr {
    Integer(_) | Symbol(_) | Residual(_) => expr
    Rational(value) => rational_to_expr(value)
    Root(index~, radicand) => normalize_root(index, radicand, options)
    RootOfUnity(order~, power~) =>
      normalize_root_of_unity(order, power, options)
    Complex(_, _) => expr
    Add(children) => normalize_add(children, options)
    Mul(children) => normalize_mul(children, options)
    IntPow(base, exp) => normalize_power(base, exp, options)
    Pow(base, exponent) => normalize_general_power(base, exponent, options)
    Div(numer, denom) => normalize_div(numer, denom, options)
  }
}

///|
fn normalize_root(
  index : EvalExpr,
  radicand : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let index = normalize_once(index, options)
  let radicand = normalize_once(radicand, options)
  guard !(index is Integer(value) && value <= 0) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard index != one else { radicand }
  Root(index~, radicand)
}

///|
fn normalize_root_of_unity(
  order : EvalExpr,
  power : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let order = normalize_once(order, options)
  let power = normalize_once(power, options)
  guard !(order is Integer(value) && value <= 0) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard !(order is Rational(value) &&
    value.denominator() != @bigint.BigInt::from_int(1)) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard !(power is Rational(value) &&
    value.denominator() != @bigint.BigInt::from_int(1)) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard order != one else { one }
  guard power != zero else { one }
  match (order, power) {
    (Integer(order), Integer(power)) => {
      let reduced = positive_mod(power, order)
      guard reduced != 0 else { one }
      guard !(order == 2 && reduced == 1) else { Integer(-1) }
      RootOfUnity(order=Integer(order), power=Integer(reduced))
    }
    (o, p) => RootOfUnity(order=o, power=p)
  }
}

///|
fn normalize_add(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let children = normalize_add_children(children, options)
  match children.length() {
    0 => zero
    1 => children[0]
    _ =>
      sum_exact_rationals(children).map_or_else(
        () => normalize_sum_children(children, options).to_expr(),
        value => rational_to_expr(value),
      )
  }
}

///|
fn normalize_add_children(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> Array[EvalExpr] raise EvalDiagnostic {
  flatten_add(children).map(child => normalize_once(child, options))
}

///|
fn normalize_sum_children(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> Polynomial[Int] raise EvalDiagnostic {
  let mut result = Polynomial::zero([])
  for child in children {
    result = normalize_add_polynomials(
      result,
      normalize_poly_from_expr(child, options.max_terms),
      options.max_terms,
    )
  }
  result
}

///|
fn normalize_mul(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let children = normalize_mul_children(children, options)
  match children.length() {
    0 => one
    1 => children[0]
    _ =>
      product_exact_rationals(children).map_or_else(
        () => normalize_product_children(children, options).to_expr(),
        value => rational_to_expr(value),
      )
  }
}

///|
fn normalize_mul_children(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> Array[EvalExpr] raise EvalDiagnostic {
  flatten_mul(children).map(child => normalize_once(child, options))
}

///|
fn normalize_product_children(
  children : Array[EvalExpr],
  options : EvalOptions,
) -> Polynomial[Int] raise EvalDiagnostic {
  let mut result = normalize_poly_one()
  for child in children {
    result = normalize_mul_polynomials(
      result,
      normalize_poly_from_expr(child, options.max_terms),
      options.max_terms,
    )
  }
  result
}

///|
fn flatten_add(children : Array[EvalExpr]) -> Array[EvalExpr] {
  let result : Array[EvalExpr] = []
  for child in children {
    match child {
      Add(grandchildren) => result.append(grandchildren)
      _ => result.push(child)
    }
  }
  result
}

///|
fn flatten_mul(children : Array[EvalExpr]) -> Array[EvalExpr] {
  let result : Array[EvalExpr] = []
  for child in children {
    match child {
      Mul(grandchildren) => result.append(grandchildren)
      _ => result.push(child)
    }
  }
  result
}

///|
const NORMALIZE_MAX_POLYNOMIAL_POWER : Int = 16

///|
const NORMALIZE_MAX_INTEGER_POWER : Int = 4096

///|
const NORMALIZE_MAX_EXPONENT_COMPOSITION : Int = 1 << 30

///|
/// An explicit conversion budget for exact integer division. Division does not
/// create new terms, so this permits inspection of an already-built numerator
/// without constraining it by the expansion budget used by normalization.
const NORMALIZE_DIVISION_CONVERSION_TERM_LIMIT : Int = 0x7FFF_FFFF

///|
/// Evaluates an integer power. Integer bases fold exactly; polynomial bases are
/// expanded. Negative integer powers of integers are not representable exactly
/// and stay as `IntPow`.
fn normalize_power(
  base : EvalExpr,
  exp : Int,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let base = normalize_once(base, options)
  if exp == 0 {
    guard base == zero else { one }
    raise EvalDiagnostic::make(InvalidPower)
  } else if exp == 1 {
    base
  } else {
    match base {
      Integer(value) => power_int(value, exp)
      IntPow(inner, m) => {
        guard exp <= NORMALIZE_MAX_EXPONENT_COMPOSITION &&
          m <= NORMALIZE_MAX_EXPONENT_COMPOSITION else {
          raise EvalDiagnostic::make(ExpressionTooLarge)
        }
        guard checked_int_mul(m, exp) is Some(combined) else {
          raise EvalDiagnostic::make(IntegerOverflow)
        }
        normalize_power(inner, combined, options)
      }
      Add(_) | Mul(_) => normalize_polynomial_power(base, exp, options)
      _ => IntPow(base, exp)
    }
  }
}

///|
fn normalize_polynomial_power(
  base : EvalExpr,
  exponent : Int,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  guard exponent <= NORMALIZE_MAX_POLYNOMIAL_POWER else {
    raise EvalDiagnostic::make(ExpressionTooLarge)
  }
  normalize_pow_polynomial(
    normalize_poly_from_expr(base, options.max_terms),
    exponent,
    options.max_terms,
  ).to_expr()
}

///|
/// exponent becomes a concrete integer. Non-integer and symbolic powers stay
/// opaque to polynomial normalization.
fn normalize_general_power(
  base : EvalExpr,
  exponent : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let base = normalize_once(base, options)
  let exponent = normalize_once(exponent, options)
  match exponent {
    Integer(value) => normalize_power(base, value, options)
    _ => Pow(base, exponent)
  }
}

///|
fn power_int(base : Int, exp : Int) -> EvalExpr raise EvalDiagnostic {
  guard exp >= 0 else {
    // e.g. 2^-1: not representable as an integer; keep the power.
    return IntPow(Integer(base), exp)
  }
  guard exp <= NORMALIZE_MAX_INTEGER_POWER else {
    raise EvalDiagnostic::make(ExpressionTooLarge)
  }
  guard checked_pow(base, exp) is Some(result) else {
    raise EvalDiagnostic::make(IntegerOverflow)
  }
  Integer(result)
}

///|
/// Normalizes a division: exact integer divisions fold; otherwise the `Div`
/// node is kept (fractions are not representable yet).
fn normalize_div(
  numer : EvalExpr,
  denom : EvalExpr,
  options : EvalOptions,
) -> EvalExpr raise EvalDiagnostic {
  let numer = normalize_once(numer, options)
  let denom = normalize_once(denom, options)
  if to_exact_rational(denom) is Some(denominator) {
    guard !rational_is_zero(denominator) else {
      raise EvalDiagnostic::make(DivisionByZero)
    }
    if to_exact_rational(numer) is Some(numerator) {
      return rational_to_expr(numerator / denominator)
    }
  }
  match denom {
    Integer(0) => raise EvalDiagnostic::make(DivisionByZero)
    Integer(divisor) =>
      match numer {
        Integer(value) =>
          if value % divisor == 0 {
            Integer(value / divisor)
          } else {
            Div(numer, denom)
          }
        _ => normalize_integer_division(numer, denom, divisor)
      }
    _ => Div(numer, denom)
  }
}

///|
fn normalize_integer_division(
  numer : EvalExpr,
  denom : EvalExpr,
  divisor : Int,
) -> EvalExpr raise EvalDiagnostic {
  let polynomial = normalize_poly_from_expr(
    numer,
    NORMALIZE_DIVISION_CONVERSION_TERM_LIMIT,
  )
  normalize_divide_polynomial(polynomial, divisor).map_or_else(
    () => Div(numer, denom),
    scaled => scaled.to_expr(),
  )
}
