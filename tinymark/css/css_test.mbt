///|
fn parse_doc(source : String) -> @core.Document {
  match @core.parse(source) {
    Ok(doc) => doc
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn compile_css_or_abort(source : String, scope? : String) -> String {
  let doc = parse_doc(source)
  match compile_css_rule_nodes(doc.nodes, scope, @core.CompileEnv::empty()) {
    Ok(rules) => rules.join("")
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
test "scopes selectors and replaces scope marker" {
  @test.assert_eq(normalize_css_scope("article"), ".article")
  @test.assert_eq(normalize_css_scope("#main"), "#main")
  @test.assert_eq(
    compile_css_or_abort("(& (:color `red`))(a:hover (:text-decoration `none`))", scope=".article"),
    ".article{color:red;}.article a:hover{text-decoration:none;}",
  )
}

///|
test "rejects selector lists and scope marker without scope" {
  let doc = parse_doc("(a,b (:color `red`))")
  match compile_css_rule_nodes(doc.nodes, None, @core.CompileEnv::empty()) {
    Ok(_) => abort("expected selector-list error")
    Err(diagnostic) =>
      @test.assert_eq(
        diagnostic.message,
        "css selector lists are not supported; write separate rules",
      )
  }

  let scoped = parse_doc("(& (:color `red`))")
  match compile_css_rule_nodes(scoped.nodes, None, @core.CompileEnv::empty()) {
    Ok(_) => abort("expected missing scope error")
    Err(diagnostic) =>
      @test.assert_eq(
        diagnostic.message,
        "css selector '&' requires a style scope",
      )
  }
}

///|
test "rejects declaration without value" {
  let doc = parse_doc("(a (:color))")
  match compile_css_rule_nodes(doc.nodes, None, @core.CompileEnv::empty()) {
    Ok(_) => abort("expected declaration error")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "css declaration requires a value: color")
  }
}
