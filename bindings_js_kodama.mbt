// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
/// Render one document to HTML with project-level context.
/// `source` may be unsaved in-memory content (for editor preview), so it
/// can differ from the entry resolved by `context_api.doc_workspace_path`.
fn kodama_to_html_impl(
  source : String,
  context_api : @kodama.ContextApi,
  options? : HtmlComposeOptions = html_compose_enable_all(),
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
) -> String raise {
  let pctx = @kodama.forester_build_project_context(context_api.docs)
  let id = context_api.doc_workspace_path

  @kodama.parse_terms_for_forester(source)
  |> @core.Stage2Extern::rewrite_apps(pctx.to_forester_rewriter(id))
  |> apply_extern_api(options.extern_api, extern_api?)
  |> @core.Stage3::pass
  |> @core.SmartPunctuation::pass
  |> apply_if(options.comment_strip, comment_strip)
  |> @core.Html::from_with(@kodama.outer_article)
  |> apply_if(options.markdown_abbrev, @core.MarkdownAbbrev::desugar)
  |> @core.Html::visit_text(text_rewriter)
  |> @core.Html::to_string
}

///|
pub fn kodama_to_html_raise(
  source : String,
  context_api : @kodama.ContextApi,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
) -> String raise {
  kodama_to_html_impl(source, context_api, text_rewriter, extern_api?)
}

///|
pub fn kodama_to_html(
  source : String,
  context_api : @kodama.ContextApi,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  language? : String = @core.default_language,
) -> String {
  try
    kodama_to_html_impl(source, context_api, text_rewriter, extern_api?)
  catch {
    err =>
      match err {
        @kodama.ForesterProjectError::IndexDocumentFailed(
          doc_id~,
          source~,
          cause~
        ) =>
          @core.render_error_to_string(
            @core.render_error(cause, source, language, doc_path=doc_id),
          )
        _ =>
          @core.render_error_to_string(
            @core.render_error(
              err,
              source,
              language,
              doc_path=context_api.doc_workspace_path,
            ),
          )
      }
  } noraise {
    html => html
  }
}

///|
/// compile Markdown (kodama) source to html
pub fn markdown_to_html(
  source : String,
  context_api : @kodama.ContextApi,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  language? : String = @core.default_language,
) -> String {
  try {
    let altsia_source = @markdown.KoMarkdown::to_altsia(source)
    let content = kodama_to_html(
      altsia_source + "\n" + altsia_prelude,
      context_api,
      text_rewriter,
      extern_api?,
      language~,
    )
    "<style>\n\{main_vscode_css}\n</style>\n\{content}"
  } catch {
    err =>
      @core.render_error_to_string(
        @core.render_error(
          err,
          source,
          language,
          doc_path=context_api.doc_workspace_path,
        ),
      )
  } noraise {
    html => html
  }
}
