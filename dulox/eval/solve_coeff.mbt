///|
/// A univariate view of a polynomial, with coefficients in ascending power
/// order. Coefficients are expressions that do not contain `variable`.
pub(all) struct UnivariatePoly {
  variable : SymbolKey
  coeffs : Array[EvalExpr]
} derive(Eq, Debug)

///|
/// Converts any supported polynomial expression into coefficients. The input
/// need not be normalized; normalization is performed while combining terms.
pub fn expr_to_univariate(
  expr : EvalExpr,
  variable : SymbolKey,
) -> UnivariatePoly raise EvalDiagnostic {
  let coefficients = try_generic_polynomial_coefficients(expr, variable) catch {
    _ => polynomial_coefficients(expr, variable)
  }
  { variable, coeffs: trim_zero_coeffs(coefficients.values), }
}

///|
/// Keeps fallback coefficient arithmetic isolated from the generic sparse
/// polynomial representation. Values are ordered by ascending variable power.
priv struct CoefficientArray {
  values : Array[EvalExpr]
}

///|
fn CoefficientArray::constant(value : EvalExpr) -> CoefficientArray {
  { values: [value], }
}

///|
fn CoefficientArray::variable() -> CoefficientArray {
  { values: [zero, one], }
}

///|
fn CoefficientArray::one() -> CoefficientArray {
  CoefficientArray::constant(one)
}

///|
fn try_generic_polynomial_coefficients(
  expr : EvalExpr,
  variable : SymbolKey,
) -> CoefficientArray raise EvalDiagnostic {
  let polynomial = expr_to_polynomial(expr)
  {
    values: polynomial.coefficients_in(variable.text).map(Polynomial::to_expr),
  }
}

///|
/// Dispatches the expression-coefficient fallback for inputs which the generic
/// integer polynomial representation cannot express.
fn polynomial_coefficients(
  expr : EvalExpr,
  variable : SymbolKey,
) -> CoefficientArray raise EvalDiagnostic {
  match expr {
    Integer(_) | Rational(_) => CoefficientArray::constant(expr)
    Symbol(symbol) =>
      if symbol == variable {
        CoefficientArray::variable()
      } else {
        CoefficientArray::constant(expr)
      }
    Add(children) => collect_sum_coefficients(children, variable)
    Mul(children) => collect_product_coefficients(children, variable)
    IntPow(base, exp) => {
      guard exp >= 0 else { raise EvalDiagnostic::make(NotPolynomial) }
      polynomial_coeff_power(polynomial_coefficients(base, variable), exp)
    }
    Div(numer, denom) => divide_coefficients(numer, denom, variable)
    Pow(_, _) | Root(_) | RootOfUnity(_) | Complex(_, _) | Residual(_) =>
      if contains_variable(expr, variable) {
        raise EvalDiagnostic::make(NotPolynomial)
      } else {
        CoefficientArray::constant(expr)
      }
  }
}

///|
fn collect_sum_coefficients(
  children : Array[EvalExpr],
  variable : SymbolKey,
) -> CoefficientArray raise EvalDiagnostic {
  let mut result : CoefficientArray = { values: [], }
  for child in children {
    result = add_coefficient_arrays(
      result,
      polynomial_coefficients(child, variable),
    )
  }
  result
}

///|
fn collect_product_coefficients(
  children : Array[EvalExpr],
  variable : SymbolKey,
) -> CoefficientArray raise EvalDiagnostic {
  let mut result = CoefficientArray::one()
  for child in children {
    result = multiply_coefficient_arrays(
      result,
      polynomial_coefficients(child, variable),
    )
  }
  result
}

///|
fn divide_coefficients(
  numer : EvalExpr,
  denom : EvalExpr,
  variable : SymbolKey,
) -> CoefficientArray raise EvalDiagnostic {
  guard !contains_variable(denom, variable) else {
    raise EvalDiagnostic::make(NotPolynomial)
  }
  let denominator = polynomial_coefficients(denom, variable)
  guard denominator.values.length() == 1 else {
    raise EvalDiagnostic::make(NotPolynomial)
  }
  divide_coefficient_array(
    polynomial_coefficients(numer, variable),
    denominator.values[0],
  )
}

///|
fn divide_coefficient_array(
  coefficients : CoefficientArray,
  denominator : EvalExpr,
) -> CoefficientArray raise EvalDiagnostic {
  {
    values: coefficients.values.map(coefficient => {
      normalize_coefficient(Div(coefficient, denominator))
    }),
  }
}

///|
/// Raises coefficients with exponentiation by squaring. Each multiplication
/// normalizes its values before the next binary-power step.
fn polynomial_coeff_power(
  base : CoefficientArray,
  exp : Int,
) -> CoefficientArray raise EvalDiagnostic {
  guard exp >= 0 else { raise EvalDiagnostic::make(NotPolynomial) }
  let mut result = CoefficientArray::one()
  let mut factor = base
  let mut remaining = exp
  while remaining > 0 {
    if remaining % 2 == 1 {
      result = multiply_coefficient_arrays(result, factor)
    }
    remaining = remaining / 2
    if remaining > 0 {
      factor = multiply_coefficient_arrays(factor, factor)
    }
  }
  result
}

///|
fn add_coefficient_arrays(
  left : CoefficientArray,
  right : CoefficientArray,
) -> CoefficientArray raise EvalDiagnostic {
  let length = if left.values.length() > right.values.length() {
    left.values.length()
  } else {
    right.values.length()
  }
  let values = Array::makei(length, i => {
    normalize_coefficient(
      Add([coefficient_at(left.values, i), coefficient_at(right.values, i)]),
    )
  })
  { values, }
}

///|
fn coefficient_at(values : Array[EvalExpr], index : Int) -> EvalExpr {
  if index < values.length() {
    values[index]
  } else {
    zero
  }
}

///|
fn multiply_coefficient_arrays(
  left : CoefficientArray,
  right : CoefficientArray,
) -> CoefficientArray raise EvalDiagnostic {
  let values : Array[EvalExpr] = Array::makei(
    left.values.length() + right.values.length() - 1,
    _ => zero,
  )
  for i in 0..<left.values.length() {
    for j in 0..<right.values.length() {
      values[i + j] = normalize_coefficient(
        Add([
          values[i + j],
          normalize_coefficient(Mul([left.values[i], right.values[j]])),
        ]),
      )
    }
  }
  { values, }
}

///|
fn coefficient_options() -> EvalOptions {
  EvalOptions::make(mode=Partial)
}

///|
fn normalize_coefficient(expr : EvalExpr) -> EvalExpr raise EvalDiagnostic {
  normalize(expr, coefficient_options())
}

///|
fn trim_zero_coeffs(coeffs : Array[EvalExpr]) -> Array[EvalExpr] {
  guard coeffs.length() > 0 else { [zero] }
  let mut last = coeffs.length() - 1
  while last > 0 && coeffs[last] == zero {
    last = last - 1
  }
  coeffs[:last + 1].to_owned()
}

///|
/// Collects the symbols appearing in an expression (used for the default
/// variable heuristic).
fn collect_symbols(expr : EvalExpr, out : Array[SymbolKey]) -> Unit {
  match expr {
    Symbol(s) => out.push(s)
    Add(children) | Mul(children) =>
      for child in children {
        collect_symbols(child, out)
      }
    IntPow(base, _) => collect_symbols(base, out)
    Pow(base, exponent) => {
      collect_symbols(base, out)
      collect_symbols(exponent, out)
    }
    Div(numer, denom) => {
      collect_symbols(numer, out)
      collect_symbols(denom, out)
    }
    Root(index~, radicand) => {
      collect_symbols(index, out)
      collect_symbols(radicand, out)
    }
    RootOfUnity(order~, power~) => {
      collect_symbols(order, out)
      collect_symbols(power, out)
    }
    Complex(re, im) => {
      collect_symbols(re, out)
      collect_symbols(im, out)
    }
    Integer(_) | Rational(_) | Residual(_) => ()
  }
}

///|
/// Default variable inference. If no variable is supplied, exactly one
/// symbol occurring in the equation must be present.
pub fn infer_variable(expr : EvalExpr) -> SymbolKey raise EvalDiagnostic {
  let symbols : Array[SymbolKey] = []
  collect_symbols(expr, symbols)
  let candidates : Array[(SymbolKey, Int)] = []
  for symbol in symbols {
    if candidates.any(item => item.0 == symbol) {
      continue
    }
    let coefficients = polynomial_coefficients(expr, symbol) catch {
      _ => CoefficientArray::constant(zero)
    }
    let degree = coefficients.values.length() - 1
    if degree > 0 {
      candidates.push((symbol, degree))
    }
  }
  match candidates.length() {
    0 => raise EvalDiagnostic::make(NoVariable)
    1 => candidates[0].0
    _ => {
      let mut best = candidates[0]
      let mut tied = false
      for candidate in candidates[1:] {
        if candidate.1 > best.1 {
          best = candidate
          tied = false
        } else if candidate.1 == best.1 {
          tied = true
        }
      }
      if tied {
        raise EvalDiagnostic::make(AmbiguousVariable)
      }
      best.0
    }
  }
}

///|
fn contains_variable(expr : EvalExpr, variable : SymbolKey) -> Bool {
  match expr {
    Integer(_) | Rational(_) | Residual(_) => false
    Symbol(symbol) => symbol == variable
    Add(children) | Mul(children) =>
      children.any(child => contains_variable(child, variable))
    IntPow(base, _) => contains_variable(base, variable)
    Pow(base, exponent) =>
      contains_variable(base, variable) || contains_variable(exponent, variable)
    Div(numer, denom) =>
      contains_variable(numer, variable) || contains_variable(denom, variable)
    Root(index~, radicand) =>
      contains_variable(index, variable) ||
      contains_variable(radicand, variable)
    RootOfUnity(order~, power~) =>
      contains_variable(order, variable) || contains_variable(power, variable)
    Complex(re, im) =>
      contains_variable(re, variable) || contains_variable(im, variable)
  }
}
