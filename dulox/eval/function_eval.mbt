///|
/// The `\eval` function spec: evaluates its argument in the current macro
/// scope and substitutes the computed result as a normal parse node.
pub fn eval_spec() -> @katex.FunctionSpec {
  @katex.FunctionSpec::make(
    ["\\eval"],
    1,
    allowed_in_argument=true,
    handler=eval_handler,
  )
}

///|
fn eval_handler(
  _context : @katex.FunctionContext,
  args : Array[@katex.ParseNode],
  _opt_args : Array[@katex.ParseNode?],
) -> @katex.ParseNode raise @katex.ParseFailure {
  let options = EvalOptions::make()
  guard args.length() == 1 else {
    raise @katex.ParseFailure::InternalInvariant(
      message="\\eval expects exactly one argument",
    )
  }
  let (body, rewrap) = strip_wrappers(args[0])
  match (Ok(lower_expr(body, options)) catch { e => Err(e) }) {
    Err(diag) => raise eval_failure(diag)
    Ok(expr) => {
      let expr = normalize(expr, options) catch {
        diag => raise eval_failure(diag)
      }
      rewrap(render(expr))
    }
  }
}

///|
fn eval_failure(diag : EvalDiagnostic) -> @katex.ParseFailure {
  InvalidArgument(message=diag.message(), loc=diag.loc())
}

///|
/// Peels off outer layout wrappers (groups, styling, color) so the inner
/// expression can be computed, and re-applies them to the rendered result.
pub fn strip_wrappers(
  node : @katex.ParseNode,
) -> (Array[@katex.ParseNode], (@katex.ParseNode) -> @katex.ParseNode) {
  match node {
    @katex.ParseNode::OrdGroup(mode~, loc~, body=original_body, ..) =>
      (
        original_body,
        inner => {
          @katex.ParseNode::OrdGroup(
            mode~,
            loc~,
            body=[inner],
            semisimple=false,
          )
        },
      )
    @katex.ParseNode::Styling(mode~, body~, style~, reset_font~) =>
      match body {
        [inner] => {
          let (inner_body, rewrap) = strip_wrappers(inner)
          (
            inner_body,
            result => {
              @katex.ParseNode::Styling(
                mode~,
                body=[rewrap(result)],
                style~,
                reset_font~,
              )
            },
          )
        }
        _ => ([node], inner => inner)
      }
    @katex.ParseNode::Color(mode~, color~, body~) =>
      match body {
        [inner] => {
          let (inner_body, rewrap) = strip_wrappers(inner)
          (
            inner_body,
            result => {
              @katex.ParseNode::Color(mode~, color~, body=[rewrap(result)])
            },
          )
        }
        _ => ([node], inner => inner)
      }
    _ => ([node], inner => inner)
  }
}
