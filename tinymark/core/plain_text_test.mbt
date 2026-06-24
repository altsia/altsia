///|
fn parse_doc(source : String) -> Document {
  match parse(source) {
    Ok(doc) => doc
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn collect_env_or_abort(doc : Document) -> CompileEnv {
  match collect_bindings(doc) {
    Ok(env) => env
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn plain_value_or_abort(value : Value, env? : CompileEnv) -> String {
  match env {
    Some(text_env) =>
      match value_to_plain_text(value, env=text_env) {
        Ok(text) => text
        Err(diagnostic) => abort(diagnostic.render())
      }
    None =>
      match value_to_plain_text(value) {
        Ok(text) => text
        Err(diagnostic) => abort(diagnostic.render())
      }
  }
}

///|
fn plain_nodes_or_abort(nodes : Array[Node]) -> String {
  match nodes_to_plain_text(nodes, None) {
    Ok(text) => text
    Err(diagnostic) => abort(diagnostic.render())
  }
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
  match nodes_to_plain_text(parse_doc("\"Hello (name)\"").nodes, None) {
    Ok(_) => abort("expected unbound interpolation")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "unbound interpolation name: name")
  }
}
