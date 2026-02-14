///|
fn altsia_to_html_impl(source : String) -> String raise {
  source
  |> Stage1::parse_spanned
  |> Stage2::pass_spanned
  |> Stage2Etale::expand_program_spanned
  |> Stage3::pass_spanned
  |> Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> Html::to_string
}

///|
fn altsia_to_html_with_visitor_impl(
  source : String,
  visitor : (String) -> String,
) -> String raise {
  source
  |> Stage1::parse_spanned
  |> Stage2::pass_spanned
  |> Stage2Etale::expand_program_spanned
  |> Stage3::pass_spanned
  |> Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> Html::cmark_desugar
  |> Html::visit_text(visitor)
  |> Html::to_string
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  altsia_to_html_impl(source)
}

///|
pub fn altsia_to_html_with_visitor_raise(
  source : String,
  visitor : (String) -> String,
) -> String raise {
  altsia_to_html_with_visitor_impl(source, visitor)
}

///|
pub fn altsia_to_html_diagnostics(
  source : String,
  language? : String = "en",
) -> Result[String, Array[RenderError]] {
  try altsia_to_html_impl(source) catch {
    err => Err([render_error(err, source, language)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_with_visitor_diagnostics(
  source : String,
  visitor : (String) -> String,
  language? : String = "en",
) -> Result[String, Array[RenderError]] {
  try altsia_to_html_with_visitor_impl(source, visitor) catch {
    err => Err([render_error(err, source, language)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_result(
  source : String,
  language? : String = "en",
) -> Result[String, Array[String]] {
  match altsia_to_html_diagnostics(source, language~) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_to_html_with_visitor_result(
  source : String,
  visitor : (String) -> String,
  language? : String = "en",
) -> Result[String, Array[String]] {
  match altsia_to_html_with_visitor_diagnostics(source, visitor, language~) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_to_html(source : String, language? : String = "en") -> String {
  match altsia_to_html_result(source, language~) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}

///|
pub fn altsia_to_html_with_visitor(
  source : String,
  visitor : (String) -> String,
  language? : String = "en",
) -> String {
  match altsia_to_html_with_visitor_result(source, visitor, language~) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}
