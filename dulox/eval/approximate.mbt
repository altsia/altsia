///|
/// A machine-precision complex approximation. A zero imaginary part is
/// represented as `ApproxValue::Real` by the public evaluator.
pub(all) struct ApproxComplex {
  real : Double
  imaginary : Double
} derive(Eq, Debug)

///|
/// The fixed-precision approximation result used until an arbitrary-precision
/// numeric backend is introduced.
pub(all) enum ApproxValue {
  Real(Double)
  Complex(ApproxComplex)
} derive(Eq, Debug)

///|
/// Approximates a closed exact expression using machine `Double` precision.
/// Free symbols and expressions whose required integer parameters cannot be
/// established exactly raise `NumericUnavailable`.
pub fn EvalExpr::approximate(
  self : EvalExpr,
) -> ApproxValue raise EvalDiagnostic {
  match self {
    Integer(value) => Real(Double::from_int(value))
    Rational(value) => Real(exact_rational_to_double(value))
    Symbol(_) | Residual(_) => raise EvalDiagnostic::make(NumericUnavailable)
    Add(children) => approximate_add(children)
    Mul(children) => approximate_mul(children)
    IntPow(base, exponent) => approximate_integer_power(base, exponent)
    Pow(base, exponent) => {
      let base = base.approximate()
      let exponent = exponent.approximate()
      approximate_power(base, exponent)
    }
    Div(numer, denom) => {
      let numer = numer.approximate()
      let denom = denom.approximate()
      approximate_divide(numer, denom)
    }
    Root(index~, radicand) => {
      guard exact_integer(index) is Some(index) && index > 0 else {
        raise EvalDiagnostic::make(NumericUnavailable)
      }
      approximate_root(index, radicand.approximate())
    }
    RootOfUnity(order~, power~) => {
      guard exact_integer(order) is Some(order) &&
        exact_integer(power) is Some(power) &&
        order > 0 else {
        raise EvalDiagnostic::make(NumericUnavailable)
      }
      approximate_root_of_unity(order, power)
    }
    Complex(real, imaginary) =>
      approximate_complex(real.approximate(), imaginary.approximate())
  }
}

///|
fn approximate_add(
  children : Array[EvalExpr],
) -> ApproxValue raise EvalDiagnostic {
  let mut result = Real(0.0)
  for child in children {
    result = add_approximate(result, child.approximate())
  }
  result
}

///|
fn approximate_mul(
  children : Array[EvalExpr],
) -> ApproxValue raise EvalDiagnostic {
  let mut result = Real(1.0)
  for child in children {
    result = multiply_approximate(result, child.approximate())
  }
  result
}

///|
fn approximate_integer_power(
  base : EvalExpr,
  exponent : Int,
) -> ApproxValue raise EvalDiagnostic {
  guard exponent != 0 else { Real(1.0) }
  let value = base.approximate()
  let mut result = Real(1.0)
  let mut factor = value
  let mut remaining = if exponent < 0 { -exponent } else { exponent }
  while remaining > 0 {
    if remaining % 2 == 1 {
      result = multiply_approximate(result, factor)
    }
    remaining = remaining / 2
    if remaining > 0 {
      factor = multiply_approximate(factor, factor)
    }
  }
  if exponent < 0 {
    divide_approximate(Real(1.0), result)
  } else {
    result
  }
}

///|
fn approximate_power(
  base : ApproxValue,
  exponent : ApproxValue,
) -> ApproxValue raise EvalDiagnostic {
  match (base, exponent) {
    (Real(base), Real(exponent)) => {
      let value = @math.pow(base, exponent)
      guard !value.is_nan() else {
        raise EvalDiagnostic::make(NumericUnavailable)
      }
      Real(value)
    }
    (Complex(base), Real(exponent)) => complex_power(base, exponent)
    _ => raise EvalDiagnostic::make(NumericUnavailable)
  }
}

///|
fn approximate_divide(
  numer : ApproxValue,
  denom : ApproxValue,
) -> ApproxValue raise EvalDiagnostic {
  divide_approximate(numer, denom)
}

///|
fn approximate_root(index : Int, radicand : ApproxValue) -> ApproxValue {
  guard index != 1 else { radicand }
  match radicand {
    Real(value) if value >= 0.0 =>
      Real(@math.pow(value, 1.0 / Double::from_int(index)))
    Real(value) if index % 2 == 1 =>
      Real(-@math.pow(-value, 1.0 / Double::from_int(index)))
    Real(value) => complex_root({ real: value, imaginary: 0.0, }, index)
    Complex(value) => complex_root(value, index)
  }
}

///|
fn approximate_root_of_unity(order : Int, power : Int) -> ApproxValue {
  let reduced = power % order
  let angle = 2.0 *
    @math.PI *
    Double::from_int(reduced) /
    Double::from_int(order)
  Complex({ real: @math.cos(angle), imaginary: @math.sin(angle), })
}

///|
fn complex_root(value : ApproxComplex, index : Int) -> ApproxValue {
  let magnitude = (value.real * value.real + value.imaginary * value.imaginary).sqrt()
  guard magnitude != 0.0 else { Real(0.0) }
  let angle = @math.atan2(value.imaginary, value.real)
  let root_magnitude = @math.pow(magnitude, 1.0 / Double::from_int(index))
  let root_angle = angle / Double::from_int(index)
  Complex({
    real: root_magnitude * @math.cos(root_angle),
    imaginary: root_magnitude * @math.sin(root_angle),
  })
}

///|
fn complex_power(value : ApproxComplex, exponent : Double) -> ApproxValue {
  let magnitude = (value.real * value.real + value.imaginary * value.imaginary).sqrt()
  guard magnitude != 0.0 else { Real(0.0) }
  let angle = @math.atan2(value.imaginary, value.real)
  let powered_magnitude = @math.pow(magnitude, exponent)
  let powered_angle = angle * exponent
  Complex({
    real: powered_magnitude * @math.cos(powered_angle),
    imaginary: powered_magnitude * @math.sin(powered_angle),
  })
}

///|
fn approximate_complex(
  real : ApproxValue,
  imaginary : ApproxValue,
) -> ApproxValue raise EvalDiagnostic {
  let real = as_real(real)
  let imaginary = as_real(imaginary)
  if imaginary == 0.0 {
    Real(real)
  } else {
    Complex({ real, imaginary, })
  }
}

///|
fn as_real(value : ApproxValue) -> Double raise EvalDiagnostic {
  match value {
    Real(value) => value
    Complex(_) => raise EvalDiagnostic::make(NumericUnavailable)
  }
}

///|
fn add_approximate(a : ApproxValue, b : ApproxValue) -> ApproxValue {
  match (a, b) {
    (Real(a), Real(b)) => Real(a + b)
    (Real(a), Complex(b)) | (Complex(b), Real(a)) =>
      Complex({ real: a + b.real, imaginary: b.imaginary, })
    (Complex(a), Complex(b)) =>
      Complex({ real: a.real + b.real, imaginary: a.imaginary + b.imaginary, })
  }
}

///|
fn multiply_approximate(a : ApproxValue, b : ApproxValue) -> ApproxValue {
  match (a, b) {
    (Real(a), Real(b)) => Real(a * b)
    (Real(a), Complex(b)) | (Complex(b), Real(a)) =>
      Complex({ real: a * b.real, imaginary: a * b.imaginary, })
    (Complex(a), Complex(b)) =>
      Complex({
        real: a.real * b.real - a.imaginary * b.imaginary,
        imaginary: a.real * b.imaginary + a.imaginary * b.real,
      })
  }
}

///|
fn divide_approximate(
  numer : ApproxValue,
  denom : ApproxValue,
) -> ApproxValue raise EvalDiagnostic {
  match (numer, denom) {
    (Real(numer), Real(denom)) => {
      guard denom != 0.0 else { raise EvalDiagnostic::make(DivisionByZero) }
      Real(numer / denom)
    }
    (Real(numer), Complex(denom)) => {
      let divisor = denom.real * denom.real + denom.imaginary * denom.imaginary
      guard divisor != 0.0 else { raise EvalDiagnostic::make(DivisionByZero) }
      Complex({
        real: numer * denom.real / divisor,
        imaginary: -numer * denom.imaginary / divisor,
      })
    }
    (Complex(numer), Real(denom)) => {
      guard denom != 0.0 else { raise EvalDiagnostic::make(DivisionByZero) }
      Complex({ real: numer.real / denom, imaginary: numer.imaginary / denom, })
    }
    (Complex(numer), Complex(denom)) => {
      let divisor = denom.real * denom.real + denom.imaginary * denom.imaginary
      guard divisor != 0.0 else { raise EvalDiagnostic::make(DivisionByZero) }
      Complex({
        real: (numer.real * denom.real + numer.imaginary * denom.imaginary) /
        divisor,
        imaginary: (numer.imaginary * denom.real - numer.real * denom.imaginary) /
        divisor,
      })
    }
  }
}
