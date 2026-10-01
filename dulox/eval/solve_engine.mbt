///|
/// The mathematical shape of a solution set for one variable.
pub(all) enum SolutionKind {
  Finite(Array[EvalExpr])
  Empty
  Universal
} derive(Eq, Debug)

///|
pub fn SolutionKind::merge(a : SolutionKind, b : SolutionKind) -> SolutionKind {
  match (a, b) {
    (Finite(a), Finite(b)) => Finite(a + b)
    (Empty, x) => x
    (x, Empty) => x
    (Universal, _) => Universal
    (_, Universal) => Universal
  }
}

///|
/// One branch of a symbolic solution, valid under its side conditions.
pub(all) struct SolutionCase {
  conditions : Array[Condition]
  solution : SolutionKind
} derive(Eq, Debug)

///|
pub(all) struct SolveRequest {
  expr : EvalExpr
  variable : SymbolKey
  domain : Domain
  assumptions : Array[Condition]
} derive(Eq, Debug)

///|
pub(all) struct SolveResult {
  variable : SymbolKey
  domain : Domain
  cases : Array[SolutionCase]
} derive(Eq, Debug)

///|
/// Solves `expr = 0` for `variable`. The expression is assumed to be a
/// normalized polynomial in the variable; closed forms are used for degrees
/// 0, 1 and 2, and higher degrees are rejected.
pub fn SolveRequest::solve(
  req : SolveRequest,
  allow_degenerate~ : Bool,
) -> SolveResult raise EvalDiagnostic {
  let poly = expr_to_univariate(req.expr, req.variable)
  solve_univariate(poly, req.domain, req.assumptions, allow_degenerate~)
}

///|
fn push_conditioned_case(
  cases : Array[SolutionCase],
  condition : Condition,
  case : SolutionCase,
  assumptions : Array[Condition],
) -> Unit {
  let conditions : Array[Condition] = [condition]
  conditions.append(case.conditions)
  if conditions_are_possible(conditions, assumptions) {
    cases.push(SolutionCase::{
      conditions: prune_conditions(conditions, assumptions),
      solution: case.solution,
    })
  }
}
