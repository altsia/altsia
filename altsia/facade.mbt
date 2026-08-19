///|
pub fn compile_project(
  project : @model.Project,
  builtin_env? : @core.CompileEnv,
) -> @model.CompiledProject raise @core.Diagnostic {
  compile_project_with_options(
    project,
    strict=false,
    builtin_env.unwrap_or(@core.CompileEnv::empty()),
  )
}

///|
pub fn compile_project_strict(
  project : @model.Project,
  builtin_env? : @core.CompileEnv,
) -> @model.CompiledProject raise @core.Diagnostic {
  compile_project_with_options(
    project,
    strict=true,
    builtin_env.unwrap_or(@core.CompileEnv::empty()),
  )
}

///|
fn compile_project_with_options(
  project : @model.Project,
  strict~ : Bool,
  env : @core.CompileEnv,
) -> @model.CompiledProject raise @core.Diagnostic {
  let parsed = @parse.parse_project_trees(project, builtin_env=env)
  let compiled = @compile.compile_parsed_project(
    project.workspace.root().to_string(),
    parsed,
  )
  if strict && compiled.diagnostics.length() > 0 {
    raise compiled.diagnostics[0]
  }
  compiled
}

///|
pub fn compile_alt_fragment(
  sources : Array[@model.SourceFile],
  entry : String,
) -> String raise @core.Diagnostic {
  let project = @model.Project::new("", sources)
  let compiled = compile_project(project)
  compiled
  .find_tree(@model.TreeSlug::from_file_path(entry))
  .map_or_else(
    () => {
      raise @model.source_diagnostic(
        entry,
        Binding,
        "missing entry tree: " + entry,
      )
    },
    tree => tree.html,
  )
}

///|
pub fn compile_alt_document(
  sources : Array[@model.SourceFile],
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> String raise @core.Diagnostic {
  let body = compile_alt_fragment(sources, entry)
  let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
  @sexp.render_html_document(
    @sexp.Attrs(Map([])),
    opts.extra_head,
    [Raw(body)],
    opts.doctype,
  )
}

///|
pub fn preview_project(
  project : @model.Project,
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> @model.PreviewResult raise @core.Diagnostic {
  let compiled = compile_project(project)
  let entry_tree_slug = @model.TreeSlug::from_file_path(entry)
  guard compiled.find_tree(entry_tree_slug) is Some(tree) else {
    raise @model.source_diagnostic(
      entry,
      Binding,
      "missing entry tree: " + entry,
    )
  }
  let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
  let html = @sexp.render_html_document(
    @sexp.Attrs(Map([])),
    opts.extra_head,
    [Raw(tree.html)],
    opts.doctype,
  )
  {
    html,
    diagnostics: compiled.diagnostics,
    source_file_dependencies: @compile.source_file_dependencies_for_entry(
      compiled.source_file_dependencies,
      tree.path,
    ),
    dangling_tree_links: @compile.dangling_tree_links_for_entry(
      compiled.dangling_tree_links,
      compiled.source_file_dependencies,
      tree.path,
    ),
    entry_tree_slug,
    title: tree.page_title(),
  }
}

///|
pub fn preview_project_structured(
  project : @model.Project,
  entry : String,
  preview_options? : @model.PreviewOptions,
  document_options? : @html.HtmlDocumentOptions,
) -> @model.StructuredPreview raise @core.Diagnostic {
  let preview_opts = preview_options.unwrap_or(@model.PreviewOptions::default())
  let parsed = @parse.parse_project_trees(project)
  let preview = @compile.compile_structured_preview(
    project.workspace.root().to_string(),
    parsed,
    entry,
    preview_opts,
  )
  let opts = document_options.unwrap_or(@html.HtmlDocumentOptions::default())
  let html = @sexp.render_html_document(
    @sexp.Attrs(Map([])),
    opts.extra_head,
    [Raw(preview.html)],
    opts.doctype,
  )
  { ..preview, html, }
}
