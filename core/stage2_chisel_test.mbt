///|
test "Stage2Chisel split_app_args separates named and positional args" {
  let source = "(badge (:class primary) hello)"
  let terms = source |> Stage1::parse |> Stage2::pass
  guard terms is [App("badge", args, _)] else { fail("expected badge call") }
  let split = Stage2Chisel::split_app_args(args)
  assert_eq(split.named_entries.length(), 1)
  assert_eq(split.positional.length(), 1)
  guard split.get_named("class") is Some(named) else {
    fail("expected :class named arg")
  }
  guard split.get_named(":class") is Some(named_with_colon) else {
    fail("expected :class named arg with colon key")
  }
  assert_eq(named.name, ":class")
  assert_eq(named_with_colon.name, ":class")
  assert_eq(named.values.length(), 1)
  guard named.values[0] is Text("primary", _) else {
    fail("expected named value primary")
  }
  guard split.positional[0] is Text("hello", _) else {
    fail("expected positional value hello")
  }
}

///|
test "Stage2Chisel split_app_args can keep layout gap spaces" {
  let source = "(badge (:class primary) hello)"
  let terms = source |> Stage1::parse |> Stage2::pass
  guard terms is [App("badge", args, _)] else { fail("expected badge call") }
  let stripped = Stage2Chisel::split_app_args(args)
  let kept = Stage2Chisel::split_app_args(args, strip_layout_gap_spaces=false)
  assert_eq(stripped.positional.length(), 1)
  assert_eq(kept.positional.length(), 2)
  guard kept.positional[0] is Text(" ", _) else {
    fail("expected first positional item to be layout gap space")
  }
}
