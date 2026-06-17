///|
pub fn compile_parsed_project(
  root : String,
  parsed : Array[@model.ParsedTree],
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  let input = CompileInput::new(root, parsed)
  ResolveState::new(input, parsed).compile_all()
}

///|
pub fn compile_structured_preview(
  root : String,
  parsed : Array[@model.ParsedTree],
  entry_path : String,
  options : @model.PreviewOptions,
) -> Result[@model.StructuredPreview, @core.Diagnostic] {
  let input = CompileInput::new(root, parsed)
  let resolver = ResolveState::new(input, parsed)
  resolver
  .compile_requested_trees()
  .bind(_ => {
    RenderState::new(
      resolver.input,
      resolver.resolved_by_slug,
      resolver.effects,
    ).render_structured_preview(entry_path, options)
  })
}

///|
fn ResolveState::compile_requested_trees(
  self : ResolveState,
) -> Result[Unit, @core.Diagnostic] {
  if self.input.source_trees_by_slug.contains("index") {
    match self.compile_resolved_tree("index") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for slug in self.input.tree_order {
    match self.compile_resolved_tree(slug) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(())
}

///|
fn ResolveState::compile_all(
  self : ResolveState,
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  self
  .compile_requested_trees()
  .bind(_ => {
    RenderState::new(self.input, self.resolved_by_slug, self.effects).render_project()
  })
}

///|
fn RenderState::render_project(
  self : RenderState,
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  self
  .compiled_tree_index()
  .map(compiled_tree_index => {
    root: self.input.root,
    trees: self.ordered_compiled_trees(compiled_tree_index),
    diagnostics: self.effects.diagnostics,
    source_file_dependencies: self.effects.source_file_dependencies,
    dangling_tree_links: self.effects.dangling_tree_links,
  })
}

///|
fn collect_initial_source_file_dependencies(
  parsed : Array[@model.ParsedTree],
) -> Array[@model.SourceFileDependency] {
  let source_file_dependencies : Array[@model.SourceFileDependency] = []
  for tree in parsed {
    for dependency in tree.source_file_dependencies {
      if !source_file_dependencies.contains(dependency) {
        source_file_dependencies.push(dependency)
      }
    }
  }
  source_file_dependencies
}
