///|
fn source(path : String, body : String) -> SourceFile {
  { path, source: body }
}

///|
fn render_entry(sources : Array[SourceFile], entry : String) -> String {
  match compile_alt_fragment(sources, entry) {
    Ok(html) => html
    Err(error) => abort(error.render())
  }
}

///|
fn compile_ok(sources : Array[SourceFile]) -> CompiledProject {
  match compile_project(Project::new("", sources)) {
    Ok(project) => project
    Err(error) => abort(error.render())
  }
}

///|
test "uses .sia definitions through normalized module name" {
  let html = render_entry(
    [
      source("index.alt", "(use `auto date.sia`)(p (auto_date.display-date))"),
      source(
        "auto date.sia", "(let today `2026-05-31`)(def display-date () (span (today)))",
      ),
    ],
    "index.alt",
  )
  @test.assert_eq(html, "<p><span>2026-05-31</span></p>")
}

///|
test "use can only import sia" {
  match
    compile_project(
      Project::new("", [
        source("index.alt", "(use `lib.alt`)"),
        source("lib.alt", "content"),
      ]),
    ) {
    Ok(_) => abort("expected .alt use to fail")
    Err(error) =>
      @test.assert_eq(error.message, "(use ...) can only import .sia files")
  }
}

///|
test "duplicate normalized sia module name is hard error" {
  match
    compile_project(
      Project::new("", [
        source("index.alt", "content"),
        source("a/auto date.sia", "(let x `a`)"),
        source("b/auto date.sia", "(let x `b`)"),
      ]),
    ) {
    Ok(_) => abort("expected duplicate module name")
    Err(error) =>
      @test.assert_eq(error.message, "duplicate .sia module name: auto_date")
  }
}

///|
test "link emits final url and records graph edges" {
  let project = compile_ok([
    source("index.alt", "(meta (:asback true))See (link `about.alt` About)."),
    source("about.alt", "(meta (:asref true :title `About page`))About."),
  ])
  let index = project.sections[0]
  let about = project.sections[1]
  @test.assert_eq(index.html, "<p>See <a href=\"about.html\">About</a>.</p>")
  @test.assert_eq(index.references, ["about"])
  @test.assert_eq(about.backlinks, ["index"])
}

///|
test "dangling local link is non fatal in normal build" {
  let project = compile_ok([
    source("index.alt", "See (link `missing.alt` Missing)."),
  ])
  @test.assert_eq(project.diagnostics.length(), 1)
  @test.assert_eq(
    project.sections[0].html,
    "<p>See <a href=\"#\" data-missing-target=\"missing.alt\">Missing</a>.</p>",
  )
}

///|
test "embed expands target content and records inferred parent" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt`)"),
    source("child.alt", "Child."),
  ])
  @test.assert_eq(
    project.sections[0].html,
    "<div class=\"embed\" data-section=\"child\"><p>Child.</p></div>",
  )
  @test.assert_eq(project.sections[1].parent, Some("index"))
}

///|
test "explicit parent overrides inferred parent" {
  let project = compile_ok([
    source("index.alt", "(embed `child.alt`)"),
    source("child.alt", "(meta (:parent `root`))Child."),
  ])
  @test.assert_eq(project.sections[1].parent, Some("root"))
}

///|
test "cyclic embed reports full chain" {
  match
    compile_project(
      Project::new("", [
        source("a.alt", "(embed `b.alt`)"),
        source("b.alt", "(embed `a.alt`)"),
      ]),
    ) {
    Ok(_) => abort("expected cyclic embed")
    Err(error) => {
      @test.assert_eq(error.message, "cyclic embed")
      @test.assert_eq(error.hint, Some("a -> b -> a"))
    }
  }
}

///|
test "finds project root from altsia.toml" {
  let root = "/private/tmp/altsia-root-test"
  @fs.create_dir(root) catch {
    IOError(_) => ()
  }
  @fs.write_string_to_file(root + "/altsia.toml", "")
  match find_project_root(root + "/nested") {
    Some(config) => @test.assert_eq(config.root, root)
    None => abort("expected project root")
  }
}
