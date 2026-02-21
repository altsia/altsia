///|
/// Render one document to HTML with project-level context.
/// `source` may be unsaved in-memory content (for editor preview), so it
/// can differ from the entry resolved by `context_api.doc_workspace_path`.
fn kodama_to_html_impl(
  source : String,
  context_api : @kodama.ContextApi,
  project_docs : Array[@kodama.DocEntry],
  options : HtmlComposeOptions,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi = @core.empty_extern_api,
) -> String raise {
  let rewriter = extern_api.to_rewriter()
  let rewriter = terms => @core.Stage2Extern::rewrite_apps(terms, rewriter)
  let project_context = @kodama.forester_build_project_context(project_docs)

  @kodama.parse_terms_for_forester(source)
  |> @core.Stage2Extern::rewrite_apps(
    project_context.to_forester_rewriter(context_api.doc_workspace_path),
  )
  |> apply_if(options.extern_api, rewriter)
  |> @core.Stage3::pass
  |> apply_if(options.comment_strip, comment_strip)
  |> @core.Html::from
  |> apply_if(options.markdown_abbrev, @core.MarkdownAbbrev::desugar)
  |> @core.Html::visit_text(text_rewriter)
  |> @core.Html::to_string
}

///|
pub fn kodama_to_html_raise(
  source : String,
  context_api : @kodama.ContextApi,
  project_docs : Array[@kodama.DocEntry],
  options : HtmlComposeOptions,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi = @core.empty_extern_api,
) -> String raise {
  kodama_to_html_impl(
    source,
    context_api,
    project_docs,
    options,
    text_rewriter,
    extern_api~,
  )
}

///|
pub fn kodama_to_html(
  source : String,
  context_api : @kodama.ContextApi,
  project_docs : Array[@kodama.DocEntry],
  options : HtmlComposeOptions,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi = @core.empty_extern_api,
  language? : String = @core.default_language,
) -> String {
  try
    kodama_to_html_impl(
      source,
      context_api,
      project_docs,
      options,
      text_rewriter,
      extern_api~,
    )
  catch {
    err =>
      @core.render_error_to_string(@core.render_error(err, source, language))
  } noraise {
    html => html
  }
}
