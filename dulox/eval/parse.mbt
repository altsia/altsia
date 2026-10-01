///|
/// Parses a TeX math expression with `\eval` registered: `\eval{...}` is
/// computed in the current macro scope and replaced by the result.
pub fn parse(
  input : String,
  settings? : @katex.Settings = Default::default(),
  extra_specs? : Array[@katex.FunctionSpec] = [],
  extra_env_specs? : Array[@katex.EnvironmentSpec] = [],
  allow_degenerate~ : Bool,
) -> Array[@katex.ParseNode] raise @katex.ParseFailure {
  @katex.parse(
    input,
    settings~,
    extra_specs=[eval_spec(), solve_spec(allow_degenerate~), ..extra_specs],
    extra_env_specs~,
  )
}
