///|
fn compile_css_or_abort(
  source : String,
  scope? : String,
) -> String raise @core.Diagnostic {
  let doc = @core.parse_abort(source)
  CSS::compile_rule_nodes(doc.nodes, scope, @core.CompileEnv::empty()).join("")
}

///|
test "scopes selectors and replaces scope marker" {
  @test.assert_eq(CSS::normalize_css_scope("article"), ".article")
  @test.assert_eq(CSS::normalize_css_scope("#main"), "#main")
  @test.assert_eq(
    compile_css_or_abort(
      "(& (:color `red`))(a:hover (:text-decoration `none`))",
      scope=".article",
    ),
    ".article{color:red;}.article a:hover{text-decoration:none;}",
  )
}

///|
test "rejects selector lists and scope marker without scope" {
  let doc = @core.parse_abort("(a,b (:color `red`))")
  try
    CSS::compile_rule_nodes(doc.nodes, None, @core.CompileEnv::empty())
  catch {
    diagnostic =>
      @test.assert_eq(
        diagnostic.message(),
        "css selector lists are not supported; write separate rules",
      )
  } noraise {
    _ => abort("expected selector-list error")
  }

  let scoped = @core.parse_abort("(& (:color `red`))")
  try
    CSS::compile_rule_nodes(scoped.nodes, None, @core.CompileEnv::empty())
  catch {
    diagnostic =>
      @test.assert_eq(
        diagnostic.message(),
        "css selector '&' requires a style scope",
      )
  } noraise {
    _ => abort("expected missing scope error")
  }
}

///|
test "rejects declaration without value" {
  let doc = @core.parse_abort("(a (:color))")
  try
    CSS::compile_rule_nodes(doc.nodes, None, @core.CompileEnv::empty())
  catch {
    diagnostic =>
      @test.assert_eq(
        diagnostic.message(),
        "css declaration requires a value: color",
      )
  } noraise {
    _ => abort("expected declaration error")
  }
}
