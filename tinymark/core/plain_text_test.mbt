///|
fn parse_doc(source : String) -> Document raise Diagnostic {
  parse(source)
}

///|
fn collect_env_or_abort(doc : Document) -> CompileEnv {
  collect_bindings(doc)
}

///|
fn plain_value_or_abort(
  value : Value,
  env? : CompileEnv,
) -> String raise Diagnostic {
  match env {
    Some(text_env) => value_to_plain_text(value, env=text_env)
    None => value_to_plain_text(value)
  }
}

///|
fn plain_nodes_or_abort(nodes : Array[Node]) -> String raise Diagnostic {
  nodes_to_plain_text(nodes, None)
}

///|
test "value to plain text handles scalar and bool values" {
  let doc = parse_doc("(let title `Important result`)(title)")
  let env = collect_env_or_abort(doc)
  match env.lookup_value("title") {
    Some(value) =>
      @test.assert_eq(plain_value_or_abort(value, env~), "Important result")
    None => abort("expected title binding")
  }
  @test.assert_eq(
    plain_value_or_abort(nodes_to_value(parse_doc("true").nodes)),
    "true",
  )
}

///|
test "nodes to plain text resolves interpolation and local bindings" {
  let doc = parse_doc(
    "(let name `Ada`)(span \"Hello (name)\")(let suffix `!`)(suffix)",
  )
  @test.assert_eq(plain_nodes_or_abort(doc.nodes), "Hello Ada!")
}

///|
test "nodes to plain text expands templates" {
  let doc = parse_doc(
    "(def badge (kind body) (body))(badge (:kind `info`) `Careful now`)",
  )
  @test.assert_eq(plain_nodes_or_abort(doc.nodes), "Careful now")
}

///|
test "nodes to plain text observes conditionals" {
  let doc = parse_doc(
    "(let show true)(let hide false)(when (show) Visible)(unless (hide) Also)",
  )
  @test.assert_eq(plain_nodes_or_abort(doc.nodes), "VisibleAlso")
}

///|
test "plain text reports unbound interpolation" {
  try nodes_to_plain_text(parse_doc("\"Hello (name)\"").nodes, None) catch {
    diagnostic =>
      @test.assert_eq(diagnostic.message(), "unbound interpolation name: name")
  } noraise {
    _ => abort("expected unbound interpolation")
  }
}

///|
test "plain text reports unbound refs" {
  try nodes_to_plain_text(parse_doc("(missing)").nodes, None) catch {
    diagnostic =>
      @test.assert_eq(diagnostic.message(), "unbound plain text name: missing")
  } noraise {
    _ => abort("expected unbound ref")
  }
}

///|
test "plain text interpolation flattens fragments" {
  let doc = parse_doc("(let label (em hot))\"Sale: (label)\"")
  @test.assert_eq(plain_nodes_or_abort(doc.nodes), "Sale: hot")
}
