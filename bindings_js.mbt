///|
fn error_to_string(err : Error) -> String {
  match err {
    Stage2Error::FunctionNameMustBePlainText(found~) =>
      "function name must be plain text: \{found}"
    Stage2Error::TemplateRequiresNameAndParamList(items~) =>
      "template requires name and param list: \{items}"
    Stage2Error::TemplateParamsMustBeList(found~) =>
      "template params must be a list: \{found}"
    Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected~,
      got~,
      args~
    ) =>
      "template arity mismatch: template=\{template_name}, " +
      "expected=\{expected}, got=\{got}, args=\{args}"
    Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~) =>
      "nested template definition is not allowed in substitution: \{term}"
    Stage3Error::AttributeExpectsAtMostOneValue(values~) =>
      "attribute expects at most one value: \{values}"
    Failure::Failure(message) => message
    _ => "\{err}"
  }
}

///|
pub fn altsia_to_html_raise(source : String) -> String raise {
  source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> Stage3::pass
  |> Html::from(f=xs => xs.filter(x => !(x is Comment(_))))
  |> Html::to_string
}

///|
pub fn altsia_to_html_with_visitor_raise(
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
