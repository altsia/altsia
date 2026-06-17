///|
pub fn compile_project(
  project : @model.Project,
  builtin_env? : @core.CompileEnv,
) -> Result[@model.CompiledProject, @core.Diagnostic] {
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
) -> Result[@model.CompiledProject, @core.Diagnostic] {
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
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  @parse.parse_project_trees(project, builtin_env=env).bind(parsed => {
    @compile.compile_parsed_project(project.root, parsed).bind(compiled => {
      if strict && compiled.diagnostics.length() > 0 {
        Err(compiled.diagnostics[0])
      } else {
        Ok(compiled)
      }
    })
  })
}

///|
pub fn compile_alt_fragment(
  sources : Array[@model.SourceFile],
  entry : String,
) -> Result[String, @core.Diagnostic] {
  let project = @model.Project::new("", sources)
  compile_project(project).bind(compiled => {
    match
      @model.compiled_tree_by_slug(compiled, @model.tree_slug_from_path(entry)) {
      Some(tree) => Ok(tree.html)
      None =>
        Err(
          @model.source_diagnostic(
            entry,
            Binding,
            "missing entry tree: " + entry,
          ),
        )
    }
  })
}

///|
pub fn compile_alt_document(
  sources : Array[@model.SourceFile],
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[String, @core.Diagnostic] {
  compile_alt_fragment(sources, entry).map(body => {
    let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
    @sexp.render_html_document(
      [],
      opts.extra_head,
      [RawHtml(body)],
      opts.doctype,
    )
  })
}

///|
pub fn preview_project(
  project : @model.Project,
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[@model.PreviewResult, @core.Diagnostic] {
  compile_project(project).bind(compiled => {
    let entry_tree_slug = @model.tree_slug_from_path(entry)
    match @model.compiled_tree_by_slug(compiled, entry_tree_slug) {
      Some(tree) => {
        let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
        let html = @sexp.render_html_document(
          [],
          opts.extra_head,
          [RawHtml(tree.html)],
          opts.doctype,
        )
        Ok({
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
          title: @model.tree_page_title(tree),
        })
      }
      None =>
        Err(
          @model.source_diagnostic(
            entry,
            Binding,
            "missing entry tree: " + entry,
          ),
        )
    }
  })
}

///|
pub fn preview_project_structured(
  project : @model.Project,
  entry : String,
  preview_options? : @model.PreviewOptions,
  document_options? : @html.HtmlDocumentOptions,
) -> Result[@model.StructuredPreview, @core.Diagnostic] {
  let preview_opts = preview_options.unwrap_or(@model.PreviewOptions::default())
  @parse.parse_project_trees(project).bind(parsed => {
    @compile.compile_structured_preview(
      project.root,
      parsed,
      entry,
      preview_opts,
    ).map(preview => {
      let opts = document_options.unwrap_or(
        @html.HtmlDocumentOptions::default(),
      )
      let html = @sexp.render_html_document(
        [],
        opts.extra_head,
        [RawHtml(preview.html)],
        opts.doctype,
      )
      { ..preview, html, }
    })
  })
}
