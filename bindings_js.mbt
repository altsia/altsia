///|
pub(all) struct RenderError {
  code : String
  message : String
  loc : SourceLoc?
} derive(Eq, Show, Debug)

///|
fn render_error(err : Error) -> RenderError {
  match err {
    Stage1Error::InvalidQuoteBlockStart(loc~) => {
      code: "stage1.invalid-quote-block-start",
      message: "quote block must start with ```",
      loc: Some(loc),
    }
    Stage1Error::InvalidApplicationStart(loc~) => {
      code: "stage1.invalid-application-start",
      message: "application must start with (",
      loc: Some(loc),
    }
    Stage1Error::UnexpectedEof(context~, loc~) => {
      code: "stage1.unexpected-eof",
      message: "unexpected EOF while parsing \{context}",
      loc: Some(loc),
    }
    Stage1Error::EmptyApplicationHead(loc~) => {
      code: "stage1.empty-application-head",
      message: "application head cannot be empty",
      loc: Some(loc),
    }
    Stage1Error::UnclosedApplication(loc~) => {
      code: "stage1.unclosed-application",
      message: "application is missing closing )",
      loc: Some(loc),
    }
    Stage1Error::UnclosedQuoteBlock(loc~) => {
      code: "stage1.unclosed-quote-block",
      message: "quote block is missing closing ```",
      loc: Some(loc),
    }
    Stage1Error::QuoteBlockRequiresPrecedingApp(loc~) => {
      code: "stage1.quote-block-requires-preceding-app",
      message: "quote block must follow a preceding application",
      loc: Some(loc),
    }
    Stage1Error::QuoteBlockMustFollowApp(loc~) => {
      code: "stage1.quote-block-must-follow-app",
      message: "quote block can only be appended to an application",
      loc: Some(loc),
    }
    Stage1Error::UnexpectedTopLevelToken(token~, loc~) => {
      code: "stage1.unexpected-top-level-token",
      message: "unexpected top-level token: \{token}",
      loc: Some(loc),
    }
    Stage2Error::FunctionNameMustBePlainText(found~, loc~) => {
      code: "stage2.function-name-not-text",
      message: "function name must be plain text: \{found}",
      loc,
    }
    Stage2Error::TemplateRequiresNameAndParamList(items~, loc~) => {
      code: "stage2.template-missing-header",
      message: "template requires name and param list: \{items}",
      loc,
    }
    Stage2Error::TemplateParamsMustBeList(found~, loc~) => {
      code: "stage2.template-params-not-list",
      message: "template params must be a list: \{found}",
      loc,
    }
    Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected~,
      got~,
      args~,
      loc~,
    ) => {
      code: "stage2-etale.template-arity-mismatch",
      message:
        "template arity mismatch: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
      loc,
    }
    Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~, loc~) => {
      code: "stage2-etale.nested-template-definition",
      message: "nested template definition is not allowed in substitution: \{term}",
      loc,
    }
    Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~) => {
      code: "stage3.attribute-too-many-values",
      message: "attribute expects at most one value: \{values}",
      loc,
    }
    Failure::Failure(message) => { code: "failure", message, loc: None }
    _ => { code: "unknown", message: "\{err}", loc: None }
  }
}

///|
fn render_error_to_string(err : RenderError) -> String {
  match err.loc {
    Some(loc) => "\{loc.line}:\{loc.column}: \{err.message}"
    None => err.message
  }
}

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
) -> Result[String, Array[RenderError]] {
  try altsia_to_html_impl(source) catch {
    err => Err([render_error(err)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_with_visitor_diagnostics(
  source : String,
  visitor : (String) -> String,
) -> Result[String, Array[RenderError]] {
  try altsia_to_html_with_visitor_impl(source, visitor) catch {
    err => Err([render_error(err)])
  } noraise {
    html => Ok(html)
  }
}

///|
pub fn altsia_to_html_result(source : String) -> Result[String, Array[String]] {
  match altsia_to_html_diagnostics(source) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(render_error_to_string))
  }
}

///|
pub fn altsia_to_html_with_visitor_result(
  source : String,
  visitor : (String) -> String,
) -> Result[String, Array[String]] {
  match altsia_to_html_with_visitor_diagnostics(source, visitor) {
    Ok(html) => Ok(html)
    Err(errors) => Err(errors.map(render_error_to_string))
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
