///|
pub extend SymbolKey with Debug::{to_repr}

///|
pub extend SymbolKey with Eq::{not_equal, equal}

///|
pub extend SymbolKey with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend MonomialFactor with Debug::{to_repr}

///|
pub extend MonomialFactor with Eq::{not_equal, equal}

///|
pub extend EvalExpr with Debug::{to_repr}

///|
pub extend EvalExpr with Eq::{not_equal, equal}

///|
pub extend ApproxComplex with Debug::{to_repr}

///|
pub extend ApproxComplex with Eq::{not_equal, equal}

///|
pub extend ApproxValue with Debug::{to_repr}

///|
pub extend ApproxValue with Eq::{not_equal, equal}

///|
pub extend EvalFailureKind with Debug::{to_repr}

///|
pub extend EvalFailureKind with Eq::{not_equal, equal}

///|
pub extend EvalDiagnostic with Debug::{to_repr}

///|
pub extend EvalDiagnostic with Eq::{not_equal, equal}

///|
pub extend EvalMode with Debug::{to_repr}

///|
pub extend EvalMode with Eq::{not_equal, equal}

///|
pub extend UnivariatePoly with Debug::{to_repr}

///|
pub extend UnivariatePoly with Eq::{not_equal, equal}

///|
pub extend Domain with Debug::{to_repr}

///|
pub extend Domain with Eq::{not_equal, equal}

///|
pub extend Condition with Debug::{to_repr}

///|
pub extend Condition with Eq::{not_equal, equal}

///|
pub extend SolutionKind with Debug::{to_repr}

///|
pub extend SolutionKind with Eq::{not_equal, equal}

///|
pub extend SolutionCase with Debug::{to_repr}

///|
pub extend SolutionCase with Eq::{not_equal, equal}

///|
pub extend SolveRequest with Debug::{to_repr}

///|
pub extend SolveRequest with Eq::{not_equal, equal}

///|
pub extend SolveResult with Debug::{to_repr}

///|
pub extend SolveResult with Eq::{not_equal, equal}
