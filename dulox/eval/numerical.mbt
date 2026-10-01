///|
/// Converts an exact expression number to the official arbitrary-precision
/// rational representation. Division nodes are accepted while expressions
/// are transitioning to the canonical `Rational` form.
fn to_exact_rational(expr : EvalExpr) -> @rational.BigRational? {
  match expr {
    Integer(value) => Some(exact_rational_from_int(value))
    Rational(value) => Some(value)
    Div(Integer(numerator), Integer(denominator)) if denominator != 0 =>
      Some(exact_rational_from_pair(numerator, denominator))
    _ => None
  }
}

///|
fn exact_rational_from_int(value : Int) -> @rational.BigRational {
  @rational.new(@bigint.BigInt::from_int(value), @bigint.BigInt::from_int(1)).unwrap()
}

///|
fn exact_rational_from_pair(
  numerator : Int,
  denominator : Int,
) -> @rational.BigRational {
  @rational.new(
    @bigint.BigInt::from_int(numerator),
    @bigint.BigInt::from_int(denominator),
  ).unwrap()
}

///|
fn bigint_abs(value : @bigint.BigInt) -> @bigint.BigInt {
  if value < @bigint.BigInt::from_int(0) {
    -value
  } else {
    value
  }
}

///|
/// Converts an exact rational back to the smallest expression representation
/// available. Integer-valued rationals outside the `Int` range remain exact
/// `Rational` nodes.
fn rational_to_expr(value : @rational.BigRational) -> EvalExpr {
  guard value.denominator() == @bigint.BigInt::from_int(1) else {
    Rational(value)
  }
  let integer = value.numerator()
  guard bigint_to_int(integer) is Some(integer) else { Rational(value) }
  Integer(integer)
}

///|
fn rational_is_zero(value : @rational.BigRational) -> Bool {
  value.numerator() == @bigint.BigInt::from_int(0)
}

///|
fn rational_is_one(value : @rational.BigRational) -> Bool {
  value.numerator() == value.denominator()
}

///|
fn exact_rational_pow(
  base : @rational.BigRational,
  exponent : Int,
) -> @rational.BigRational {
  guard exponent >= 0 else { exact_rational_pow(base.reciprocal(), -exponent) }
  let mut result = exact_rational_from_int(1)
  let mut factor = base
  let mut remaining = exponent
  while remaining > 0 {
    if remaining % 2 == 1 {
      result = result * factor
    }
    remaining = remaining / 2
    if remaining > 0 {
      factor = factor * factor
    }
  }
  result
}

///|
fn exact_integer(expr : EvalExpr) -> Int? {
  match expr {
    Integer(value) => Some(value)
    Rational(value) if value.denominator() == @bigint.BigInt::from_int(1) =>
      bigint_to_int(value.numerator())
    _ => None
  }
}

///|
fn bigint_to_int(value : @bigint.BigInt) -> Int? {
  guard value.compare_int(-2147483648) >= 0 &&
    value.compare_int(2147483647) <= 0 else {
    None
  }
  Some(value.to_int())
}

///|
fn positive_mod(value : Int, modulus : Int) -> Int {
  let remainder = value % modulus
  if remainder < 0 {
    remainder + modulus
  } else {
    remainder
  }
}

///|
fn sum_exact_rationals(values : Array[EvalExpr]) -> @rational.BigRational? {
  let mut result = exact_rational_from_int(0)
  for value in values {
    guard to_exact_rational(value) is Some(value) else { return None }
    result = result + value
  }
  Some(result)
}

///|
fn product_exact_rationals(values : Array[EvalExpr]) -> @rational.BigRational? {
  let mut result = exact_rational_from_int(1)
  for value in values {
    guard to_exact_rational(value) is Some(value) else { return None }
    result = result * value
  }
  Some(result)
}

///|
fn exact_rational_to_double(
  value : @rational.BigRational,
) -> Double raise EvalDiagnostic {
  let magnitude = bigint_abs(value.numerator())
  let integer = magnitude / value.denominator()
  guard integer.compare_int64(9223372036854775807L) <= 0 else {
    raise EvalDiagnostic::make(NumericUnavailable)
  }
  let mut result = integer.to_int64().to_double()
  let mut remainder = magnitude % value.denominator()
  let mut place = 0.1
  for _ in 0..<17 {
    guard remainder != @bigint.BigInt::from_int(0) else { break }
    remainder = remainder * @bigint.BigInt::from_int(10)
    let digit = remainder / value.denominator()
    result = result + Double::from_int(digit.to_int()) * place
    remainder = remainder % value.denominator()
    place = place * 0.1
  }
  if value.numerator() < @bigint.BigInt::from_int(0) {
    -result
  } else {
    result
  }
}

///|
fn gcd_int(a : Int, b : Int) -> Int {
  let mut x = a
  let mut y = b
  while y != 0 {
    let t = x % y
    x = y
    y = t
  }
  x
}

///|
/// Adds two `Int` values when the result fits in the evaluator's Int range.
fn checked_int_add(a : Int, b : Int) -> Int? {
  let sum = a.to_int64() + b.to_int64()
  if sum > 2147483647L || sum < -2147483648L {
    None
  } else {
    Some(sum.to_int())
  }
}

///|
/// Multiplies two `Int` values when the result fits in the evaluator's Int range.
fn checked_int_mul(a : Int, b : Int) -> Int? {
  let product = a.to_int64() * b.to_int64()
  if product > 2147483647L || product < -2147483648L {
    None
  } else {
    Some(product.to_int())
  }
}

///|
/// Computes a non-negative integer power with overflow detection.
/// Binary exponentiation keeps the number of multiplications logarithmic.
fn checked_pow(base : Int, exp : Int) -> Int? {
  guard exp >= 0 else { return None }
  let mut result = 1
  let mut factor = base
  let mut remaining = exp
  while remaining > 0 {
    if remaining % 2 == 1 {
      guard checked_int_mul(result, factor) is Some(value) else { return None }
      result = value
    }
    remaining = remaining / 2
    if remaining > 0 {
      guard checked_int_mul(factor, factor) is Some(value) else { return None }
      factor = value
    }
  }
  Some(result)
}

///|
fn perfect_nth_root(radicand : Int, index : Int) -> Int? {
  guard radicand >= 0 && index > 0 else { None }
  guard radicand > 1 else { Some(radicand) }
  guard index <= 30 else { None }
  let root = floor_nth_root(radicand, index)
  guard checked_pow(root, index) is Some(value) && value == radicand else {
    None
  }
  Some(root)
}

///|
fn nth_root_factor(radicand : Int, index : Int) -> Int {
  guard radicand > 1 && index > 1 && index <= 30 else { 1 }
  let mut factor = floor_nth_root(radicand, index)
  while factor > 1 {
    if checked_pow(factor, index) is Some(power) && radicand % power == 0 {
      return factor
    }
    factor = factor - 1
  }
  1
}

///|
fn floor_nth_root(radicand : Int, index : Int) -> Int {
  let mut low = 1
  let mut high = radicand
  while low < high {
    let middle = low + (high - low + 1) / 2
    if checked_pow(middle, index) is Some(value) && value <= radicand {
      low = middle
    } else {
      high = middle - 1
    }
  }
  low
}
