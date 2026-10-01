///|
/// Bounded result folding used by `\solve`: numeric/rational arithmetic,
/// radical extraction, complex canonicalization, and division-by-number
/// factor-out. This is a small, focused rewrite (not the general `normalize`);
/// the input polynomial is assumed to already be in normalized form, and only
/// the closed-form discriminant and roots are simplified here.
pub fn EvalExpr::simplify_solve(
  expr : EvalExpr,
  domain : Domain,
  max_rewrite_steps? : Int = 256,
) -> EvalExpr raise EvalDiagnostic {
  rewrite_to_fixed_point(expr, max_rewrite_steps, current => {
    current.simplify_once(domain)
  })
}

///|
fn EvalExpr::simplify_once(
  expr : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match expr {
    Integer(_) | Rational(_) | Symbol(_) | Residual(_) => expr
    Root(index~, radicand) =>
      simplify_root(
        index.simplify_once(domain),
        radicand.simplify_once(domain),
        domain,
      )
    RootOfUnity(order~, power~) =>
      simplify_root_of_unity(
        order.simplify_once(domain),
        power.simplify_once(domain),
      )
    Complex(re, im) =>
      complex(re.simplify_once(domain), im.simplify_once(domain))
    Add(c) => simplify_add(c.map(e => e.simplify_once(domain)))
    Mul(c) => simplify_mul(c.map(e => e.simplify_once(domain)))
    IntPow(base, exp) => base.simplify_once(domain).simplify_pow(exp)
    Pow(base, exponent) => simplify_general_pow(base, exponent, domain)
    Div(numer, denom) =>
      simplify_div(
        numer.simplify_once(domain),
        denom.simplify_once(domain),
        domain,
      )
  }
}

///|
/// Sums children, folding pure-number/rational parts (placed last) and merging
/// numeric `Complex` children into a single complex value.
fn simplify_add(children : Array[EvalExpr]) -> EvalExpr {
  let collected = collect_add_terms(flatten_add(children))
  rebuild_add(collected)
}

///|
priv struct AddCollection {
  numeric_sum : @rational.BigRational
  complex_real : @rational.BigRational
  complex_imaginary : @rational.BigRational
  has_complex : Bool
  remaining : Array[EvalExpr]
}

///|
fn collect_add_terms(children : Array[EvalExpr]) -> AddCollection {
  let mut numeric_sum = exact_rational_from_int(0)
  let mut complex_real = exact_rational_from_int(0)
  let mut complex_imaginary = exact_rational_from_int(0)
  let mut has_complex = false
  let remaining : Array[EvalExpr] = []
  for child in children {
    if to_exact_rational(child) is Some(value) {
      numeric_sum = numeric_sum + value
      continue
    }
    match child {
      Complex(re, im) =>
        if (to_exact_rational(re), to_exact_rational(im))
          is (Some(real), Some(imaginary)) {
          has_complex = true
          complex_real = complex_real + real
          complex_imaginary = complex_imaginary + imaginary
        } else {
          remaining.push(child)
        }
      _ => remaining.push(child)
    }
  }
  { numeric_sum, complex_real, complex_imaginary, has_complex, remaining, }
}

///|
fn rebuild_add(collection : AddCollection) -> EvalExpr {
  let numeric_sum = collection.numeric_sum
  let complex_real = collection.complex_real
  let complex_imaginary = collection.complex_imaginary
  let has_complex = collection.has_complex
  let remaining = collection.remaining
  if has_complex {
    let value = complex(
      rational_to_expr(complex_real + numeric_sum),
      rational_to_expr(complex_imaginary),
    )
    if remaining.length() == 0 {
      return value
    }
    if value == zero {
      return simplify_add(remaining)
    }
    return Add([value, ..remaining])
  }
  if remaining.length() == 0 {
    return rational_to_expr(numeric_sum)
  }
  if rational_is_zero(numeric_sum) {
    if remaining.length() == 1 {
      return remaining[0]
    }
    return Add(remaining)
  }
  Add([..remaining, rational_to_expr(numeric_sum)])
}

///|
/// Multiplies children: folds numeric/rational factors into a scalar, merges
/// numeric `Complex` factors via complex multiplication, and drops unit
/// factors.
fn simplify_mul(children : Array[EvalExpr]) -> EvalExpr raise EvalDiagnostic {
  let flat = simplify_unit_root_factors(flatten_mul(children))
  let collected = collect_mul_factors(flat)
  rebuild_mul(collected)
}

///|
priv struct MulCollection {
  numeric_product : @rational.BigRational
  complex_real : @rational.BigRational
  complex_imaginary : @rational.BigRational
  has_complex : Bool
  remaining : Array[EvalExpr]
}

///|
fn collect_mul_factors(children : Array[EvalExpr]) -> MulCollection {
  let mut numeric_product = exact_rational_from_int(1)
  let mut complex_real = exact_rational_from_int(0)
  let mut complex_imaginary = exact_rational_from_int(0)
  let mut has_complex = false
  let remaining : Array[EvalExpr] = []
  for child in children {
    if to_exact_rational(child) is Some(value) {
      numeric_product = numeric_product * value
      continue
    }
    match child {
      Complex(re, im) =>
        if (to_exact_rational(re), to_exact_rational(im))
          is (Some(real), Some(imaginary)) {
          if has_complex {
            let (old_real, old_imaginary) = (complex_real, complex_imaginary)
            complex_real = old_real * real - old_imaginary * imaginary
            complex_imaginary = old_real * imaginary + old_imaginary * real
          } else {
            complex_real = real
            complex_imaginary = imaginary
            has_complex = true
          }
        } else {
          remaining.push(child)
        }
      _ => remaining.push(child)
    }
  }
  { numeric_product, complex_real, complex_imaginary, has_complex, remaining, }
}

///|
fn rebuild_mul(collection : MulCollection) -> EvalExpr {
  let numeric_product = collection.numeric_product
  let complex_real = collection.complex_real
  let complex_imaginary = collection.complex_imaginary
  let has_complex = collection.has_complex
  let remaining = collection.remaining
  if rational_is_zero(numeric_product) {
    return zero
  }
  if has_complex {
    let value = complex(
      rational_to_expr(complex_real * numeric_product),
      rational_to_expr(complex_imaginary * numeric_product),
    )
    if remaining.length() == 0 {
      return value
    }
    if value == one {
      if remaining.length() == 1 {
        return remaining[0]
      }
      return Mul(remaining)
    }
    return Mul([value, ..remaining])
  }
  if rational_is_one(numeric_product) {
    if remaining.length() == 0 {
      return one
    }
    if remaining.length() == 1 {
      return remaining[0]
    }
    return Mul(remaining)
  }
  let scalar = rational_to_expr(numeric_product)
  if remaining.length() == 0 {
    return scalar
  }
  Mul([scalar, ..remaining])
}

///|
fn simplify_div(
  numer : EvalExpr,
  denom : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  guard !simplifies_zero_quotient(numer, denom) else { zero }
  match simplify_exact_rational_division(numer, denom) {
    Some(result) => result
    None => simplify_nonrational_division(numer, denom, domain)
  }
}

///|
fn simplifies_zero_quotient(numer : EvalExpr, denom : EvalExpr) -> Bool {
  to_exact_rational(numer) is Some(value) &&
  rational_is_zero(value) &&
  is_definitely_nonzero(denom)
}

///|
fn simplify_exact_rational_division(
  numer : EvalExpr,
  denom : EvalExpr,
) -> EvalExpr? {
  match (to_exact_rational(numer), to_exact_rational(denom)) {
    (_, Some(denominator)) if rational_is_zero(denominator) => None
    (Some(numerator), Some(denominator)) =>
      Some(rational_to_expr(numerator / denominator))
    _ => None
  }
}

///|
fn simplify_nonrational_division(
  numer : EvalExpr,
  denom : EvalExpr,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match denom {
    Integer(1) => numer
    Integer(0) => Div(numer, denom)
    Integer(divisor) => simplify_integer_division(numer, divisor, domain)
    _ => Div(numer, denom)
  }
}

///|
fn simplify_integer_division(
  numer : EvalExpr,
  divisor : Int,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  match numer {
    Integer(0) => zero
    Mul(children) => simplify_mul([Div(one, Integer(divisor)), ..children])
    Complex(re, im) => simplify_complex_division(re, im, divisor, domain)
    _ => Div(numer, Integer(divisor))
  }
}

///|
fn simplify_complex_division(
  real : EvalExpr,
  imaginary : EvalExpr,
  divisor : Int,
  domain : Domain,
) -> EvalExpr raise EvalDiagnostic {
  complex(
    simplify_div(real, Integer(divisor), domain),
    simplify_div(imaginary, Integer(divisor), domain),
  )
}

///|
fn is_definitely_nonzero(expr : EvalExpr) -> Bool {
  match expr {
    Integer(value) => value != 0
    Rational(value) => !rational_is_zero(value)
    Root(index=_, radicand) => is_definitely_nonzero(radicand)
    RootOfUnity(..) => true
    Mul(children) => all_children_nonzero(children)
    _ => false
  }
}

///|
fn all_children_nonzero(children : Array[EvalExpr]) -> Bool {
  let mut result = true
  for child in children {
    if !is_definitely_nonzero(child) {
      result = false
      break
    }
  }
  result
}
