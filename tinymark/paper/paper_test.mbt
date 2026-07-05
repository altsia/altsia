///|
let test_span : @core.SourceSpan = {
  source_id: None,
  line: 1,
  column: 1,
  marker_column: 1,
  line_text: "test",
}

///|
test "renders paper css for known presets" {
  match paper_style_css({ slate_name: "a4", staple: false }, test_span) {
    Ok(css) => {
      @test.assert_eq(css.contains("@page"), true)
      @test.assert_eq(css.contains("size: A4"), true)
      @test.assert_eq(css.contains(".paper"), true)
    }
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
test "staple adds binding margin" {
  match paper_style_css({ slate_name: "a4", staple: true }, test_span) {
    Ok(css) => @test.assert_eq(css.contains("calc(24mm + 8mm)"), true)
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
test "rejects unknown paper preset" {
  match paper_style_css({ slate_name: "letter", staple: false }, test_span) {
    Ok(_) => abort("expected unknown paper error")
    Err(diagnostic) =>
      @test.assert_eq(diagnostic.message, "unknown paper slate: letter")
  }
}
