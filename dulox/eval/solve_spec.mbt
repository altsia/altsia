///|
/// The `\solve` function spec: solves an equation for the optional variable.
pub fn solve_spec(allow_degenerate~ : Bool) -> @katex.FunctionSpec {
  @katex.FunctionSpec::make(
    ["\\solve"],
    1,
    num_optional_args=1,
    allowed_in_argument=true,
    handler=(ctx, args, opt_args) => {
      solve_handler(ctx, args, opt_args, allow_degenerate~)
    },
  )
}

///|
fn solve_handler(
  _context : @katex.FunctionContext,
  args : Array[@katex.ParseNode],
  opt_args : Array[@katex.ParseNode?],
  allow_degenerate~ : Bool,
) -> @katex.ParseNode raise @katex.ParseFailure {
  guard args.length() == 1 else {
    raise @katex.ParseFailure::InternalInvariant(
      message="\\solve expects exactly one argument",
    )
  }
  let (body, rewrap) = strip_wrappers(args[0])
  rewrap(solve_body(body, opt_args, allow_degenerate~))
}

///|
fn solve_body(
  body : Array[@katex.ParseNode],
  opt_args : Array[@katex.ParseNode?],
  allow_degenerate~ : Bool,
) -> @katex.ParseNode raise @katex.ParseFailure {
  let options = EvalOptions::make(mode=Strict)
  try {
    let (lhs_nodes, rhs_nodes) = split_equation(body)
    let lhs = lower_expr(lhs_nodes, options)
    let rhs = lower_expr(rhs_nodes, options)
    let expr = normalize(Add([lhs, Mul([neg_one, rhs])]), options)
    let variable = variable_from_opt(opt_args).map_or_else(
      () => infer_variable(expr),
      variable => variable,
    )
    let poly = expr_to_univariate(expr, variable)
    solve_render(solve_univariate(poly, Domain::C, [], allow_degenerate~))
  } catch {
    diag => raise eval_failure(diag)
  }
}

///|
/// Extracts the variable from an optional `\\solve[x]` argument. An omitted
/// argument returns `None`; a present but invalid argument is an error.
fn variable_from_opt(
  opt_args : Array[@katex.ParseNode?],
) -> SymbolKey? raise EvalDiagnostic {
  guard opt_args.get(0) is Some(Some(node)) else { return None }
  let (body, _) = strip_wrappers(node)
  let options = EvalOptions::make(mode=Strict)
  let expr = lower_expr(body, options) catch {
    _ => raise EvalDiagnostic::make(InvalidVariable)
  }
  match expr {
    Symbol(symbol) => Some(symbol)
    _ => raise EvalDiagnostic::make(InvalidVariable)
  }
}
