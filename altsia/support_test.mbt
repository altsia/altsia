///|
fn source(path : String, body : String) -> @model.SourceFile {
  { path, source: body }
}

///|
fn render_entry(sources : Array[@model.SourceFile], entry : String) -> String {
  match compile_alt_fragment(sources, entry) {
    Ok(html) => html
    Err(error) => abort(error.render())
  }
}

///|
fn compile_ok(sources : Array[@model.SourceFile]) -> @model.CompiledProject {
  match compile_project(@model.Project::new("", sources)) {
    Ok(project) => project
    Err(error) => abort(error.render())
  }
}

///|
fn slug(value : String) -> @model.TreeSlug {
  @model.TreeSlug::parse(value)
}

///|
fn parse_doc(path : String, body : String) -> @core.Document {
  let source_info : @core.SourceInfo = {
    id: Some(path),
    line_offset: 0,
    column_offset: 0,
  }
  match @core.parse(body, source_info~) {
    Ok(doc) => doc
    Err(error) => abort(error.render())
  }
}
