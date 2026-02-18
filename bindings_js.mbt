///|
fn to_html_tree(source : String) -> @core.Html raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
  |> @core.Stage3::pass
  |> @core.Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
}

///|
fn altsia_to_html_impl(source : String) -> String raise {
  to_html_tree(source) |> @core.Html::to_string
}

///|
fn altsia_to_html_with_extern_api_impl(
  source : String,
  text_rewriter : (String) -> String,
  app_rewriter : @core.AppRewriter,
) -> String raise {
  source
  |> @core.Stage1::parse
  |> @core.Stage2::pass
  |> @core.Stage2Etale::expand_program
  |> @core.Stage2Etale::rewrite_apps(app_rewriter)
  |> @core.Stage3::pass
  |> @core.Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> CommonMark::desugar
  |> @core.Html::visit_text(text_rewriter)
  |> @core.Html::to_string
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  altsia_to_html_impl(source)
}

///|
pub fn altsia_to_html_with_extern_api_raise(
  source : String,
  text_rewriter : (String) -> String,
  app_rewriter : @core.AppRewriter,
) -> String raise {
  altsia_to_html_with_extern_api_impl(source, text_rewriter, app_rewriter)
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
pub fn altsia_to_html_with_extern_api_diagnostics(
  source : String,
  text_rewriter : (String) -> String,
  app_rewriter : @core.AppRewriter,
  language? : String = @core.default_language,
) -> Result[String, Array[@core.RenderError]] {
  try
    altsia_to_html_with_extern_api_impl(source, text_rewriter, app_rewriter)
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
pub fn altsia_to_html_with_extern_api_result(
  source : String,
  text_rewriter : (String) -> String,
  app_rewriter : @core.AppRewriter,
  language? : String = @core.default_language,
) -> Result[String, Array[String]] {
  match
    altsia_to_html_with_extern_api_diagnostics(
      source,
      text_rewriter,
      app_rewriter,
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
pub fn altsia_to_html_with_extern_api(
  source : String,
  text_rewriter : (String) -> String,
  app_rewriter : @core.AppRewriter,
  language? : String = @core.default_language,
) -> String {
  match
    altsia_to_html_with_extern_api_result(
      source,
      text_rewriter,
      app_rewriter,
      language~,
    ) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}
