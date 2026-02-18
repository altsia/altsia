///|
pub(all) struct ExternApi {
  visit_text : (String) -> String
}

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
fn apply_extern_api(html : @core.Html, extern_api : ExternApi) -> @core.Html {
  html
  |> CommonMark::desugar
  |> @core.Html::visit_element(element => {
    let { name, attrs, children } = element
    let name = match name {
      "read" => ""
      _ => name
    }
    { name, attrs, children: children.map(h => CommonMark::desugar(h)) }
  })
  |> @core.Html::visit_text(extern_api.visit_text)
}

///|
fn altsia_to_html_impl(source : String) -> String raise {
  to_html_tree(source) |> @core.Html::to_string
}

///|
fn altsia_to_html_with_extern_api_impl(
  source : String,
  extern_api : ExternApi,
) -> String raise {
  to_html_tree(source) |> apply_extern_api(extern_api) |> @core.Html::to_string
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  altsia_to_html_impl(source)
}

///|
pub fn altsia_to_html_with_extern_api_raise(
  source : String,
  extern_api : ExternApi,
) -> String raise {
  altsia_to_html_with_extern_api_impl(source, extern_api)
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
  extern_api : ExternApi,
  language? : String = @core.default_language,
) -> Result[String, Array[@core.RenderError]] {
  try altsia_to_html_with_extern_api_impl(source, extern_api) catch {
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
  extern_api : ExternApi,
  language? : String = @core.default_language,
) -> Result[String, Array[String]] {
  match
    altsia_to_html_with_extern_api_diagnostics(source, extern_api, language~) {
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
  extern_api : ExternApi,
  language? : String = @core.default_language,
) -> String {
  match altsia_to_html_with_extern_api_result(source, extern_api, language~) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}

