///|
fn parse_nodes_or_error(source : String) -> Result[Array[Node], Diagnostic] {
  parse(source).map(doc => doc.nodes)
}

///|
test "quoted strings parse interpolation parts" {
  match parse_nodes_or_error("\"Hello (name)\"") {
    Ok([TextInterp([Literal("Hello "), Name("name")], _)]) => ()
    Ok(_) => abort("expected structured interpolation")
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
test "quoted string interpolation uses name grammar" {
  match parse_nodes_or_error("\"Hello (first name)\"") {
    Ok(_) => abort("expected invalid interpolation")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "invalid interpolation name")
  }
}

///|
test "escaped interpolation marker stays literal" {
  match parse_nodes_or_error("\"Hello \\(name)\"") {
    Ok([TextInterp([Literal("Hello (name)")], _)]) => ()
    Ok(_) => abort("expected literal interpolation marker")
    Err(diagnostic) => abort(diagnostic.render())
  }
}
