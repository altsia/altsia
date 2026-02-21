///|
/// Render one document to HTML with project-level context.
/// `source` may be unsaved in-memory content (for editor preview), so it
/// can differ from the entry resolved by `context_api.doc_workspace_path`.
fn kodama_to_html_impl(
  source : String,
  context_api : ContextApi,
  project_docs : Array[DocEntry],
) -> String raise {
  let project_context = forester_build_project_context(project_docs)
  parse_terms_for_forester(source)
  |> @core.Stage2Extern::rewrite_apps(
    project_context.to_forester_rewriter(context_api.doc_workspace_path),
  )
  |> @core.Stage3::pass
  |> @core.Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> @core.MarkdownAbbrev::desugar
  |> @core.Html::to_string
}

///|
pub fn kodama_to_html_raise(
  source : String,
  context_api : ContextApi,
  project_docs : Array[DocEntry],
) -> String raise {
  kodama_to_html_impl(source, context_api, project_docs)
}

///|
pub fn kodama_to_html(
  source : String,
  context_api : ContextApi,
  project_docs : Array[DocEntry],
  language? : String = @core.default_language,
) -> String {
  try kodama_to_html_impl(source, context_api, project_docs) catch {
    err => @core.render_error_to_string(@core.render_error(err, source, language))
  } noraise {
    html => html
  }
}
