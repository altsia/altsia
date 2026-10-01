///|
pub fn solve_univariate(
  poly : UnivariatePoly,
  domain : Domain,
  assumptions : Array[Condition],
  allow_degenerate~ : Bool,
) -> SolveResult raise EvalDiagnostic {
  let coeffs = trim_zero_coeffs(poly.coeffs)
  match coeffs.length() - 1 {
    0 => constant_equation(poly.variable, domain, coeffs[0], assumptions)
    1 =>
      linear_equation(
        poly.variable,
        domain,
        coeffs[1],
        coeffs[0],
        assumptions,
        allow_degenerate~,
      )
    2 =>
      quadratic_equation(
        poly.variable,
        coeffs[2],
        coeffs[1],
        coeffs[0],
        domain,
        assumptions,
        allow_degenerate~,
      )
    3 =>
      cubic_equation(
        poly.variable,
        coeffs[3],
        coeffs[2],
        coeffs[1],
        coeffs[0],
        domain,
        assumptions,
        allow_degenerate~,
      )
    _ => raise EvalDiagnostic::make(NoClosedForm)
  }
}
