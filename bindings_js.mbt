// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn to_html_tree(
  source : String,
  options : HtmlComposeOptions,
  extern_api? : @core.ExternApi,
) -> @core.Html raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
  |> apply_extern_api(options.extern_api, extern_api?)
  |> @core.Stage3::pass
  |> @core.SmartPunctuation::pass
  |> apply_if(options.comment_strip, comment_strip)
  |> @core.Html::from
  |> apply_if(options.markdown_abbrev, @core.MarkdownAbbrev::desugar)
}

///|
#inline
fn[T] apply_if(value : T, enabled : Bool, transformer : (T) -> T) -> T {
  guard enabled else { value }
  transformer(value)
}

///|
fn apply_extern_api(
  terms : Array[@core.Term],
  enable_extern_api : Bool,
  extern_api? : @core.ExternApi,
) -> Array[@core.Term] raise {
  guard enable_extern_api && extern_api is Some(extern_api) else { terms }
  @core.Stage2Extern::rewrite_apps_raise(terms, extern_api.to_rewriter_raise())
}

///|
fn comment_strip(doc : Array[@core.Piece]) -> Array[@core.Piece] {
  doc.filter(x => !(x is Comment(_)))
}

///|
fn to_html_tree_default(source : String) -> @core.Html raise {
  to_html_tree(source, html_compose_options_default())
}

///|
fn altsia_to_html_impl(source : String) -> String raise {
  to_html_tree_default(source) |> @core.Html::to_string
}

///|
fn altsia_to_html_with_rewriter_impl(
  source : String,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  options : HtmlComposeOptions,
) -> String raise {
  source
  |> to_html_tree(options, extern_api?)
  |> @core.Html::visit_text(text_rewriter)
  |> @core.Html::to_string
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  altsia_to_html_impl(source)
}

///|
pub fn altsia_to_html_with_rewriter_raise(
  source : String,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
) -> String raise {
  altsia_to_html_with_rewriter_impl(
    source,
    text_rewriter,
    extern_api?,
    html_compose_enable_all(),
  )
}

///|
pub fn altsia_to_html_diagnostics(
  source : String,
  language? : String = @core.default_language,
) -> Result[String, Array[@core.RenderError]] {
  try altsia_to_html_impl(source) catch {
    err => Err([@core.render_error(err, source, language)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_with_rewriter_diagnostics(
  source : String,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  language? : String = @core.default_language,
) -> Result[String, Array[@core.RenderError]] {
  try
    altsia_to_html_with_rewriter_impl(
      source,
      text_rewriter,
      extern_api?,
      html_compose_enable_all(),
    )
  catch {
    err => Err([@core.render_error(err, source, language)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_result(
  source : String,
  language? : String = @core.default_language,
) -> Result[String, Array[String]] {
  match altsia_to_html_diagnostics(source, language~) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(@core.render_error_to_string))
  }
}

///|
pub fn altsia_to_html_with_rewriter_result(
  source : String,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  language? : String = @core.default_language,
) -> Result[String, Array[String]] {
  match
    altsia_to_html_with_rewriter_diagnostics(
      source,
      text_rewriter,
      extern_api?,
      language~,
    ) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(@core.render_error_to_string))
  }
}

///|
pub fn altsia_to_html(
  source : String,
  language? : String = @core.default_language,
) -> String {
  match altsia_to_html_result(source, language~) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}

///|
pub fn altsia_to_html_with_rewriter(
  source : String,
  text_rewriter : (String) -> String,
  extern_api? : @core.ExternApi,
  language? : String = @core.default_language,
) -> String {
  match
    altsia_to_html_with_rewriter_result(
      source,
      text_rewriter,
      extern_api?,
      language~,
    ) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}
