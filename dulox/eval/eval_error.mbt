///|
pub(all) enum EvalFailureKind {
  UnsupportedNode
  InvalidNumber
  DivisionByZero
  InvalidPower
  IntegerOverflow
  ExpressionTooLarge
  TooManyRewriteSteps
  NotPolynomial
  NotNormalized
  InvalidEquation
  InvalidVariable
  NoVariable
  AmbiguousVariable
  NoSolution
  TriviallyAll
  NoRealSolution
  NoClosedForm
  NumericUnavailable
} derive(Eq, Debug)

///|
pub(all) suberror EvalDiagnostic {
  Fail(EvalFailureKind, @katex.SourceLocation?)
} derive(Eq, Debug)

///|
pub fn EvalDiagnostic::make(
  kind : EvalFailureKind,
  loc? : @katex.SourceLocation? = None,
) -> EvalDiagnostic {
  EvalDiagnostic::Fail(kind, loc)
}

///|
pub fn EvalDiagnostic::loc(self : EvalDiagnostic) -> @katex.SourceLocation? {
  match self {
    EvalDiagnostic::Fail(_, loc) => loc
  }
}

///|
pub fn EvalDiagnostic::message(self : EvalDiagnostic) -> String {
  let kind = match self {
    EvalDiagnostic::Fail(kind, _) => kind
  }
  match kind {
    UnsupportedNode => "unsupported construct in \\eval"
    InvalidNumber => "invalid number in \\eval"
    DivisionByZero => "division by zero in \\eval"
    InvalidPower => "invalid exponent in \\eval"
    IntegerOverflow => "integer overflow in \\eval"
    ExpressionTooLarge => "expression too large in \\eval"
    TooManyRewriteSteps => "expression too complex to evaluate in \\eval"
    NotPolynomial => "\\solve requires a polynomial in the variable"
    NotNormalized => "\\solve expression is not in a supported polynomial form"
    InvalidEquation => "\\solve expects one equation with a single equals sign"
    InvalidVariable => "\\solve variable must be a single symbol"
    NoVariable => "\\solve needs a variable; use \\solve[x]{...}"
    AmbiguousVariable =>
      "multiple candidate variables; use \\solve[x]{...} to pick one"
    NoSolution => "the polynomial has no roots"
    TriviallyAll => "the polynomial vanishes for every value of the variable"
    NoRealSolution => "the polynomial has no real roots"
    NoClosedForm => "no general closed form exists for this degree"
    NumericUnavailable => "numeric solving is not available yet"
  }
}

///|
/// How unsupported subtrees are treated during lowering.
pub(all) enum EvalMode {
  /// Unsupported subtrees abort with an `UnsupportedNode` diagnostic.
  Strict
  /// Unsupported subtrees are kept as opaque `Residual` nodes.
  Partial
} derive(Eq, Debug)

///|
pub(all) struct EvalOptions {
  mode : EvalMode
  max_terms : Int
  max_rewrite_steps : Int
}

///|
pub fn EvalOptions::make(
  mode? : EvalMode = Partial,
  max_terms? : Int = 256,
  max_rewrite_steps? : Int = 256,
) -> EvalOptions {
  { mode, max_terms, max_rewrite_steps, }
}
