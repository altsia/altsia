///|
fn source(path : String, body : String) -> @model.SourceFile {
  { path, source: body }
}

///|
fn render_entry(
  sources : Array[@model.SourceFile],
  entry : String,
) -> String raise @core.Diagnostic {
  compile_alt_fragment(sources, entry)
}

///|
fn compile_ok(
  sources : Array[@model.SourceFile],
) -> @model.CompiledProject raise @core.Diagnostic {
  compile_project(@model.Project::new("", sources))
}

///|
fn slug(value : String) -> @model.TreeSlug {
  @model.TreeSlug::parse(value)
}

///|
fn parse_doc(
  path : String,
  body : String,
) -> @core.Document raise @core.Diagnostic {
  let source_info : @core.SourceInfo = {
    id: Some(path),
    line_offset: 0,
    column_offset: 0,
  }
  @core.parse(body, source_info~)
}
