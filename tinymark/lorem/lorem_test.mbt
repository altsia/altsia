///|
fn parse_doc(source : String) -> @core.Document {
  match @core.parse(source) {
    Ok(doc) => doc
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn collect_env(doc : @core.Document) -> @core.CompileEnv {
  match @core.collect_bindings(doc) {
    Ok(env) => env
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn lorem_text_or_abort(source : String) -> String {
  let doc = parse_doc(source)
  let last = doc.nodes.length() - 1
  guard doc.nodes[last] is Element("lorem", attrs, children, span) else {
    abort("expected lorem element")
  }
  match compile_lorem_text(attrs, children, collect_env(doc), span) {
    Ok(text) => text
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
test "generates lorem text from default and named schemes" {
  @test.assert_eq(lorem_text_or_abort("(lorem 3)").length() > 0, true)
  @test.assert_eq(
    lorem_text_or_abort("(lorem (:scheme `xiaoyaoyou`) 2)").length() > 0,
    true,
  )
}

///|
test "resolves count from bindings and interpolation" {
  let expected = lorem_text_or_abort("(lorem 3)")
  @test.assert_eq(lorem_text_or_abort("(let count 3)(lorem (count))"), expected)
  @test.assert_eq(
    lorem_text_or_abort("(let count 3)(lorem \"(count)\")"),
    expected,
  )
}

///|
test "reports missing and invalid count" {
  let missing = parse_doc("(lorem)")
  guard missing.nodes[0] is Ref("lorem", span) else {
    abort("expected lorem ref")
  }
  match compile_lorem_text([], [], @core.CompileEnv::empty(), span) {
    Ok(_) => abort("expected missing count error")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "(lorem ...) requires a count")
  }

  let invalid = parse_doc("(lorem abc)")
  guard invalid.nodes[0] is Element("lorem", attrs, children, span) else {
    abort("expected lorem element")
  }
  match compile_lorem_text(attrs, children, @core.CompileEnv::empty(), span) {
    Ok(_) => abort("expected invalid count error")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "lorem <count> requires an integer")
  }
}
