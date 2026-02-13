///|
fn render_html(source : String) -> String raise {
  source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> Stage3::pass
  |> Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> Html::to_string
}

///|
fn render_html_with_visitor(
  source : String,
  visitor : (String) -> String,
) -> String raise {
  source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> Stage3::pass
  |> Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> Html::cmark_desugar
  |> Html::visit_text(visitor)
  |> Html::to_string
}

///|
fn error_to_string(err : Error) -> String {
  match err {
    Failure::Failure(message) => message
    _ => "\{err}"
  }
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  render_html(source)
}

///|
pub fn altsia_to_html_with_visitor_raise(
  source : String,
  visitor : (String) -> String,
) -> String raise {
  render_html_with_visitor(source, visitor)
}

///|
pub fn altsia_to_html_result(source : String) -> Result[String, Array[String]] {
  try altsia_to_html_raise(source) catch {
    err => Err([error_to_string(err)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_with_visitor_result(
  source : String,
  visitor : (String) -> String,
) -> Result[String, Array[String]] {
  try altsia_to_html_with_visitor_raise(source, visitor) catch {
    err => Err([error_to_string(err)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html(source : String) -> String {
  match altsia_to_html_result(source) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}

///|
pub fn altsia_to_html_with_visitor(
  source : String,
  visitor : (String) -> String,
) -> String {
  match altsia_to_html_with_visitor_result(source, visitor) {
    Ok(html) => html
    Err(errors) => errors.join("\n")
  }
}
