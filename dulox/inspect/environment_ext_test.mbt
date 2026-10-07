///|
/// An extension environment that wraps its single-cell body in `(...)`,
/// registered by name `parens`.
fn parens_environment_handler(
  context : @katex.EnvironmentContext,
  _args : Array[@katex.ParseNode],
  _opt_args : Array[@katex.ParseNode?],
) -> @katex.ParseNode raise @katex.ParseFailure {
  let array = (context.parse_array)({
    columns: None,
    array_stretch: Some(1.0),
    hskip_before_and_after: false,
    cell_style: @katex.StyleLevel::TextStyle,
    max_columns: Some(1),
    single_row: true,
    empty_single_row: true,
    auto_tag: None,
    leqno: false,
    add_jot: false,
    column_separation_type: None,
  })
  @katex.ParseNode::LeftRight(
    mode=context.mode,
    body=[array],
    left="(",
    right=")",
    right_color=None,
  )
}

///|
/// An extension environment that requires one mandatory argument (ignored in
/// this handler) and wraps its body in `[...]`.
fn bracket_environment_handler(
  context : @katex.EnvironmentContext,
  args : Array[@katex.ParseNode],
  _opt_args : Array[@katex.ParseNode?],
) -> @katex.ParseNode raise @katex.ParseFailure {
  guard args.length() == 1 else {
    raise @katex.ParseFailure::InternalInvariant(
      message="expected one mandatory environment argument",
    )
  }
  let array = (context.parse_array)({
    columns: None,
    array_stretch: Some(1.0),
    hskip_before_and_after: false,
    cell_style: @katex.StyleLevel::TextStyle,
    max_columns: Some(1),
    single_row: true,
    empty_single_row: true,
    auto_tag: None,
    leqno: false,
    add_jot: false,
    column_separation_type: None,
  })
  @katex.ParseNode::LeftRight(
    mode=context.mode,
    body=[array],
    left="[",
    right="]",
    right_color=None,
  )
}

///|
/// Overrides the builtin `matrix` environment with a `{...}`-wrapped body.
fn curly_matrix_environment_handler(
  context : @katex.EnvironmentContext,
  _args : Array[@katex.ParseNode],
  _opt_args : Array[@katex.ParseNode?],
) -> @katex.ParseNode raise @katex.ParseFailure {
  let array = (context.parse_array)({
    columns: None,
    array_stretch: Some(1.0),
    hskip_before_and_after: false,
    cell_style: @katex.StyleLevel::TextStyle,
    max_columns: Some(1),
    single_row: true,
    empty_single_row: true,
    auto_tag: None,
    leqno: false,
    add_jot: false,
    column_separation_type: None,
  })
  @katex.ParseNode::LeftRight(
    mode=context.mode,
    body=[array],
    left="\\{",
    right="\\}",
    right_color=None,
  )
}

///|
test "register a custom environment via extra_env_specs" {
  let spec = @katex.EnvironmentSpec::make(
    ["parens"],
    0,
    handler=parens_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse("\\begin{parens}a+b\\end{parens}", extra_env_specs=[spec]),
    ),
    "(a + b)",
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse("x \\begin{parens}a+b\\end{parens} y", extra_env_specs=[spec]),
    ),
    "x (a + b) y",
  )
}

///|
test "a single spec can register multiple environment names" {
  let spec = @katex.EnvironmentSpec::make(
    ["parens", "parens*"],
    0,
    handler=parens_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse(
        "\\begin{parens}a\\end{parens}\\begin{parens*}b\\end{parens*}",
        extra_env_specs=[spec],
      ),
    ),
    "(a) (b)",
  )
}

///|
test "custom environment with a mandatory argument" {
  let spec = @katex.EnvironmentSpec::make(
    ["bracket"],
    1,
    handler=bracket_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse("\\begin{bracket}{x}a+b\\end{bracket}", extra_env_specs=[
        spec,
      ]),
    ),
    "[a + b]",
  )
}

///|
/// KaTeX treats a mandatory argument as the next group or single token, so a
/// bare token is consumed as the argument and the array body stays empty.
test "mandatory environment argument is consumed from the next token" {
  let spec = @katex.EnvironmentSpec::make(
    ["bracket"],
    1,
    handler=bracket_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse("\\begin{bracket}a\\end{bracket}", extra_env_specs=[spec]),
    ),
    "[]",
  )
}

///|
test "extra_env_specs override builtin environments by name" {
  let spec = @katex.EnvironmentSpec::make(
    ["matrix"],
    0,
    handler=curly_matrix_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @katex.parse("\\begin{matrix}a\\end{matrix}", extra_env_specs=[spec]),
    ),
    "{a}",
  )
}

///|
test "mismatched begin and end still raises for extended environments" {
  let spec = @katex.EnvironmentSpec::make(
    ["parens"],
    0,
    handler=parens_environment_handler,
  )
  @test.assert_raise(() => {
    @katex.parse("\\begin{parens}a\\end{other}", extra_env_specs=[spec])
  })
}

///|
test "unregistered environment still raises" {
  @test.assert_raise(() => @katex.parse("\\begin{nope}a\\end{nope}"))
}

///|
test "eval.parse passes extra_env_specs through" {
  let spec = @katex.EnvironmentSpec::make(
    ["parens"],
    0,
    handler=parens_environment_handler,
  )
  @test.assert_eq(
    @unicode.render(
      @eval.parse(
        "\\begin{parens}a+b\\end{parens}",
        extra_env_specs=[spec],
        allow_degenerate=false,
      ),
    ),
    "(a + b)",
  )
}
