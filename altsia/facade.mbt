///|
pub fn compile_rich_content(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[RichContent, @core.Diagnostic] {
  match env {
    Some(env) => @content.compile_rich_content(doc, env~)
    None => @content.compile_rich_content(doc)
  }
}

///|
pub fn compile_project(
  project : Project,
  builtin_env? : @core.CompileEnv,
) -> Result[CompiledProject, @core.Diagnostic] {
  match builtin_env {
    Some(env) => compile_project_with_options(project, strict=false, env)
    None =>
      compile_project_with_options(
        project,
        strict=false,
        @core.CompileEnv::empty(),
      )
  }
}

///|
pub fn compile_project_strict(
  project : Project,
  builtin_env? : @core.CompileEnv,
) -> Result[CompiledProject, @core.Diagnostic] {
  match builtin_env {
    Some(env) => compile_project_with_options(project, strict=true, env)
    None =>
      compile_project_with_options(
        project,
        strict=true,
        @core.CompileEnv::empty(),
      )
  }
}

///|
fn compile_project_with_options(
  project : Project,
  strict~ : Bool,
  env : @core.CompileEnv,
) -> Result[CompiledProject, @core.Diagnostic] {
  let parsed = match @parse.parse_project_trees(project, builtin_env=env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match @compile.compile_parsed_project(project.root, parsed) {
    Err(error) => Err(error)
    Ok(compiled) =>
      if strict && compiled.diagnostics.length() > 0 {
        Err(compiled.diagnostics[0])
      } else {
        Ok(compiled)
      }
  }
}

///|
pub fn compile_alt_fragment(
  sources : Array[SourceFile],
  entry : String,
) -> Result[String, @core.Diagnostic] {
  let project = @model.Project::new("", sources)
  match compile_project(project) {
    Err(error) => Err(error)
    Ok(compiled) =>
      match
        @model.compiled_tree_by_slug(
          compiled,
          @model.tree_slug_from_path(entry),
        ) {
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
  }
}

///|
pub fn compile_alt_document(
  sources : Array[SourceFile],
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[String, @core.Diagnostic] {
  match compile_alt_fragment(sources, entry) {
    Err(error) => Err(error)
    Ok(body) => {
      let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
      Ok(
        @sexp.render_html_document(
          [],
          opts.extra_head,
          [RawHtml(body)],
          opts.doctype,
        ),
      )
    }
  }
}

///|
pub fn preview_project(
  project : Project,
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[PreviewResult, @core.Diagnostic] {
  match compile_project(project) {
    Err(error) => Err(error)
    Ok(compiled) => {
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
    }
  }
}

///|
pub fn check_project(
  project : Project,
) -> Result[CompiledProject, @core.Diagnostic] {
  compile_project_strict(project)
}

///|
pub fn expand_dirty_sources(
  project : CompiledProject,
  dirty_sources : Array[String],
) -> Array[String] {
  @compile.expand_dirty_sources(project, dirty_sources)
}
