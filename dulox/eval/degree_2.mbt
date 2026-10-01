///|
/// ax² + bx + c = 0
fn quadratic_equation(
  variable : SymbolKey,
  a : EvalExpr,
  b : EvalExpr,
  c : EvalExpr,
  domain : Domain,
  assumptions : Array[Condition],
  allow_degenerate~ : Bool,
) -> SolveResult raise EvalDiagnostic {
  let cases : Array[SolutionCase] = []

  // a ≠ 0
  if conditions_are_possible([NonZero(a)], assumptions) {
    let conditions : Array[Condition] = [NonZero(a)]

    let discriminant = EvalExpr::simplify_solve(
      IntPow(b, 2) + Mul([Integer(-4), a, c]),
      domain,
    )

    // discriminant is not an integer, but the domain is R, so we need to add a condition that the discriminant is non-negative.
    if domain is R && !(discriminant is Integer(_)) {
      conditions.push(NonNegative(discriminant))
    }

    cases.push(SolutionCase::{
      conditions: prune_conditions(conditions, assumptions),
      solution: quadratic_solution(a, b, discriminant, domain),
    })
  }

  // a = 0, #[degeneration]
  if allow_degenerate && conditions_are_possible([Zero(a)], assumptions) {
    let linear = linear_equation(
      variable,
      domain,
      b,
      c,
      assumptions,
      allow_degenerate~,
    )
    linear.cases.each(c => push_conditioned_case(cases, Zero(a), c, assumptions))
  }

  SolveResult::{ variable, domain, cases, }
}

///|
fn quadratic_solution(
  a : EvalExpr,
  b : EvalExpr,
  discriminant : EvalExpr,
  domain : Domain,
) -> SolutionKind raise EvalDiagnostic {
  // Δ < 0 ∧ x ∈ ℝ
  if discriminant is Integer(n) && n < 0 && domain is R {
    return Empty
  }
  let sqrt_discriminant = Root(index=two, discriminant).simplify_solve(domain)
  let denominator = (two * a).simplify_solve(domain)
  let negated_b = (-b).simplify_solve(domain)

  // (-b + √Δ) / 2a
  let x1 = (negated_b + sqrt_discriminant) / denominator
  let x1 = x1.simplify_solve(domain)

  // Δ = 0, #[singularity]
  guard !(discriminant == zero) else { Finite([x1]) }

  // Δ ≠ 0, (-b - √Δ) / 2a
  // There is no need to simplify negative radical terms here, 
  // because there is no simpler form for negative radical terms in all domains. 
  // For example, -√2 is already in simplest form. 
  let x2 = (negated_b + -sqrt_discriminant) / denominator
  let x2 = x2.simplify_solve(domain)
  Finite([x1, x2])
}
