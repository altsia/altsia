///|
fn constant_equation(
  variable : SymbolKey,
  domain : Domain,
  constant : EvalExpr,
  assumptions : Array[Condition],
) -> SolveResult {
  // case 1: 0 = 0, all values are solutions
  if constant == zero {
    return SolveResult::{
      variable,
      domain,
      cases: [{ conditions: [], solution: Universal, }],
    }
  }

  // case 2: c = 0 for c ≠ 0, no values are solutions
  if constant is Integer(value) && value != 0 {
    return { variable, domain, cases: [{ conditions: [], solution: Empty, }], }
  }

  // case 3: c = 0 for symbolic c, two branches, one for c = 0 and one for c ≠ 0
  let zero_case = SolutionCase::{
    conditions: prune_conditions([Zero(constant)], assumptions),
    solution: Universal,
  }
  let nonzero_case = SolutionCase::{
    conditions: prune_conditions([NonZero(constant)], assumptions),
    solution: Empty,
  }
  { variable, domain, cases: [zero_case, nonzero_case], }
}
