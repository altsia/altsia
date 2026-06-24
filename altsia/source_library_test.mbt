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
test "records use library dependency" {
  let project = compile_ok([
    source("index.alt", "(use `lib.sia`)(p (lib.value))"),
    source("lib.sia", "(let value `ok`)"),
  ])
  @test.assert_eq(project.source_file_dependencies, [
    { source: "index.alt", target: "lib.sia", kind: @model.LibraryUse },
  ])
}

///|
test "use can only import sia" {
  match
    compile_project(
      @model.Project::new("", [
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
      @model.Project::new("", [
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
