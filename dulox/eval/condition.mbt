///|
/// A side condition on a solution: the expression is required to be non-zero
/// (e.g. a symbolic leading coefficient) or non-negative (e.g. a symbolic
/// discriminant in the real domain).
pub(all) enum Condition {
  Zero(EvalExpr)
  NonZero(EvalExpr)
  NonNegative(EvalExpr)
} derive(Eq, Debug)

///|
fn Condition::is_satisfied(condition : Condition, value : Int) -> Bool {
  match condition {
    Zero(_) => value == 0
    NonZero(_) => value != 0
    NonNegative(_) => value >= 0
  }
}

///|
fn Condition::expr(cond : Condition) -> EvalExpr {
  let Zero(expr) | NonZero(expr) | NonNegative(expr) = cond
  expr
}

///|
fn Condition::implied(cond : Condition, assumptions : Array[Condition]) -> Bool {
  for assumption in assumptions {
    match (cond, assumption) {
      (Zero(a), Zero(b)) | (NonZero(a), NonZero(b)) => return a == b
      (NonNegative(a), NonNegative(b)) => return a == b
      _ => ()
    }
  }
  false
}

///|
fn Condition::contradicted(
  cond : Condition,
  assumptions : Array[Condition],
) -> Bool {
  for assumption in assumptions {
    match (cond, assumption) {
      (Zero(a), NonZero(b)) | (NonZero(a), Zero(b)) => return a == b
      _ => ()
    }
  }
  false
}

///|
/// Best-effort condition pruning: a condition whose expression folds to a
/// concrete number is decided exactly, and conditions already assumed are
/// dropped.
fn prune_conditions(
  conditions : Array[Condition],
  assumptions : Array[Condition],
) -> Array[Condition] {
  let result : Array[Condition] = []
  for cond in conditions {
    let mut should_retain = !cond.implied(assumptions)
    if cond.contradicted(assumptions) {
      should_retain = false
    }
    if should_retain {
      if (Some(cond.expr().simplify_solve(Domain::C)) catch { _ => None })
        is Some(Integer(_)) {
        should_retain = false
      }
    }
    if should_retain {
      result.push(cond)
    }
  }
  result
}

///|
fn conditions_are_possible(
  conditions : Array[Condition],
  assumptions : Array[Condition],
) -> Bool {
  for cond in conditions {
    guard !cond.implied(assumptions) else { continue }
    guard !cond.contradicted(assumptions) else { return false }

    let result = Some(EvalExpr::simplify_solve(cond.expr(), Domain::C)) catch {
      _ => None
    }
    if result is Some(Integer(value)) && !cond.is_satisfied(value) {
      return false
    }
  }
  true
}
