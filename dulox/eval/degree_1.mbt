///|
/// ax + b = 0
fn linear_equation(
  variable : SymbolKey,
  domain : Domain,
  a : EvalExpr,
  b : EvalExpr,
  assumptions : Array[Condition],
  allow_degenerate~ : Bool,
) -> SolveResult raise EvalDiagnostic {
  let cases : Array[SolutionCase] = []

  // a ≠ 0
  if conditions_are_possible([NonZero(a)], assumptions) {
    let root = (-b / a).simplify_solve(domain)
    cases.push(SolutionCase::{
      conditions: prune_conditions([NonZero(a)], assumptions),
      solution: Finite([root]),
    })
  }

  // a = 0, #[degeneration]
  if allow_degenerate && conditions_are_possible([Zero(a)], assumptions) {
    let degenerate = constant_equation(variable, domain, b, assumptions)
    for case in degenerate.cases {
      push_conditioned_case(cases, Zero(a), case, assumptions)
    }
  }
  { variable, domain, cases, }
}
