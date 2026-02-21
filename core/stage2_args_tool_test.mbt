///|
test "Stage2Extern split_app_args separates named and positional args" {
  let source = "(badge (:class primary) hello)"
  let terms = source
    |> Stage1::parse
    |> Stage2::pass
  guard terms is [App("badge", args, _)] else {
    fail("expected badge call")
  }
  let split = Stage2Extern::split_app_args(args)
  assert_eq(split.named.length(), 1)
  assert_eq(split.positional.length(), 1)
  assert_eq(split.named[0].name, ":class")
  assert_eq(split.named[0].values.length(), 1)
  guard split.named[0].values[0] is Text("primary", _) else {
    fail("expected named value primary")
  }
  guard split.positional[0] is Text("hello", _) else {
    fail("expected positional value hello")
  }
}

///|
test "Stage2Extern split_app_args can keep layout gap spaces" {
  let source = "(badge (:class primary) hello)"
  let terms = source
    |> Stage1::parse
    |> Stage2::pass
  guard terms is [App("badge", args, _)] else {
    fail("expected badge call")
  }
  let stripped = Stage2Extern::split_app_args(args)
  let kept = Stage2Extern::split_app_args(args, strip_layout_gap_spaces=false)
  assert_eq(stripped.positional.length(), 1)
  assert_eq(kept.positional.length(), 2)
  guard kept.positional[0] is Text(" ", _) else {
    fail("expected first positional item to be layout gap space")
  }
}

