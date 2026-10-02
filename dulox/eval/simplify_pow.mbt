///|
/// Maximum exponent for eagerly expanding a complex integer power.
///
/// Complex powers are expanded by repeated multiplication below. Keeping this
/// bound at 16 limits the simplifier to a small, predictable amount of work
/// and prevents large expression trees; it is a performance bound, not a
/// mathematical restriction on complex exponentiation.
const COMPLEX_POW_MAX_EXPONENT : Int = 16

///|
/// Simplifies an integer power when doing so preserves exactness and keeps
/// evaluation bounded. Cases that may overflow, change domain-sensitive
/// semantics, or grow too large remain as `IntPow`.
fn EvalExpr::simplify_pow(
  base : EvalExpr,
  exp : Int,
) -> EvalExpr raise EvalDiagnostic {
  // Zero and first powers have canonical, constant-size forms.
  guard exp != 0 else { one }
  guard exp != 1 else { base }
  // Leave negative powers opaque so reciprocal and zero-domain semantics are
  // not changed by an eager rewrite.
  guard exp > 0 else { IntPow(base, exp) }
  match base {
    // Fold only when the checked integer computation fits in `Int`.
    Integer(value) =>
      if checked_pow(value, exp) is Some(result) {
        Integer(result)
      } else {
        IntPow(base, exp)
      }
    // Exact rationals can be raised without introducing approximation.
    Rational(value) if exp > 0 =>
      rational_to_expr(exact_rational_pow(value, exp))
    // For a unit root, raising to a power multiplies its root index. Fall
    // back if the indices are not exact integers or the product overflows.
    RootOfUnity(order~, power~) => {
      guard (exact_integer(order), exact_integer(power))
        is (Some(order), Some(power)) else {
        return IntPow(base, exp)
      }
      guard checked_int_mul(power, exp) is Some(product) else {
        return IntPow(base, exp)
      }
      simplify_root_of_unity(Integer(order), Integer(product)) catch {
        _ => IntPow(base, exp)
      }
    }
    // Handle an integer quotient that has not yet been canonicalized as a
    // `Rational`, preserving exactness on both numerator and denominator.
    Div(Integer(p), Integer(q)) if q != 0 =>
      if (checked_pow(p, exp), checked_pow(q, exp))
        is (Some(numer), Some(denom)) {
        rational_to_expr(exact_rational_from_pair(numer, denom))
      } else {
        IntPow(base, exp)
      }
    Complex(re, im) => simplify_complex_power(base, re, im, exp)
    // Unknown bases are retained because no exact bounded rewrite is known.
    _ => IntPow(base, exp)
  }
}

///|
fn simplify_complex_power(
  original : EvalExpr,
  real : EvalExpr,
  imaginary : EvalExpr,
  exponent : Int,
) -> EvalExpr raise EvalDiagnostic {
  guard exponent <= COMPLEX_POW_MAX_EXPONENT else { IntPow(original, exponent) }
  let mut result = complex(one, zero)
  let mut factor = complex(real, imaginary)
  let mut remaining = exponent
  while remaining > 0 {
    if remaining % 2 == 1 {
      result = simplify_mul([result, factor])
    }
    remaining = remaining / 2
    if remaining > 0 {
      factor = simplify_mul([factor, factor])
    }
  }
  result
}

///|
/// Other powers retain their domain-sensitive semantics and remain opaque.
fn simplify_general_pow(
  base : EvalExpr,
  exponent : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  let base = base.simplify_once(domain)
  let exponent = exponent.simplify_once(domain)
  match exponent {
    Integer(value) => base.simplify_pow(value)
    Rational(value) if value.denominator() == @bigint.BigInt::from_int(1) =>
      if exact_integer(Rational(value)) is Some(value) {
        base.simplify_pow(value)
      } else {
        Pow(base, exponent)
      }
    _ => Pow(base, exponent)
  }
}
