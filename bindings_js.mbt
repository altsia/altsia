///|
pub(all) struct RenderError {
  code : String
  phase : String
  message : String
  loc : SourceLoc?
  source_excerpt : String?
} derive(Eq, Show, Debug)

///|
fn source_excerpt_for(source : String, loc : SourceLoc?) -> String? {
  match loc {
    None => None
    Some(loc) => {
      let radius = 20
      let len = source.length()
      let start = if loc.start_offset - radius < 0 {
        0
      } else {
        loc.start_offset - radius
      }
      let end = if loc.end_offset + radius > len {
        len
      } else {
        loc.end_offset + radius
      }
      if start >= end {
        None
      } else {
        Some(source.unsafe_substring(start=start, end=end))
      }
    }
  }
}

///|
fn make_render_error(
  code : String,
  phase : String,
  message : String,
  loc : SourceLoc?,
  source : String,
) -> RenderError {
  { code, phase, message, loc, source_excerpt: source_excerpt_for(source, loc) }
}

///|
fn render_error(err : Error, source : String) -> RenderError {
  match err {
    Stage1Error::InvalidQuoteBlockStart(loc~) =>
      make_render_error(
        "stage1.invalid-quote-block-start",
        "stage1.parse",
        "quote block must start with ```",
        Some(loc),
        source,
      )
    Stage1Error::InvalidApplicationStart(loc~) =>
      make_render_error(
        "stage1.invalid-application-start",
        "stage1.parse",
        "application must start with (",
        Some(loc),
        source,
      )
    Stage1Error::UnexpectedEof(context~, loc~) =>
      make_render_error(
        "stage1.unexpected-eof",
        "stage1.parse",
        "unexpected EOF while parsing \{context}",
        Some(loc),
        source,
      )
    Stage1Error::EmptyApplicationHead(loc~) =>
      make_render_error(
        "stage1.empty-application-head",
        "stage1.parse",
        "application head cannot be empty",
        Some(loc),
        source,
      )
    Stage1Error::UnclosedApplication(loc~) =>
      make_render_error(
        "stage1.unclosed-application",
        "stage1.parse",
        "application is missing closing )",
        Some(loc),
        source,
      )
    Stage1Error::UnclosedQuoteBlock(loc~) =>
      make_render_error(
        "stage1.unclosed-quote-block",
        "stage1.parse",
        "quote block is missing closing ```",
        Some(loc),
        source,
      )
    Stage1Error::QuoteBlockRequiresPrecedingApp(loc~) =>
      make_render_error(
        "stage1.quote-block-requires-preceding-app",
        "stage1.parse",
        "quote block must follow a preceding application",
        Some(loc),
        source,
      )
    Stage1Error::QuoteBlockMustFollowApp(loc~) =>
      make_render_error(
        "stage1.quote-block-must-follow-app",
        "stage1.parse",
        "quote block can only be appended to an application",
        Some(loc),
        source,
      )
    Stage1Error::UnexpectedTopLevelToken(token~, loc~) =>
      make_render_error(
        "stage1.unexpected-top-level-token",
        "stage1.parse",
        "unexpected top-level token: \{token}",
        Some(loc),
        source,
      )
    Stage2Error::FunctionNameMustBePlainText(found~, loc~) =>
      make_render_error(
        "stage2.function-name-not-text",
        "stage2.elaborate",
        "function name must be plain text: \{found}",
        loc,
        source,
      )
    Stage2Error::TemplateRequiresNameAndParamList(items~, loc~) =>
      make_render_error(
        "stage2.template-missing-header",
        "stage2.elaborate",
        "template requires name and param list: \{items}",
        loc,
        source,
      )
    Stage2Error::TemplateParamsMustBeList(found~, loc~) =>
      make_render_error(
        "stage2.template-params-not-list",
        "stage2.elaborate",
        "template params must be a list: \{found}",
        loc,
        source,
      )
    Stage2Error::InternalInvariantViolation(context~, loc~) =>
      make_render_error(
        "stage2.internal-invariant-violation",
        "stage2.elaborate",
        "internal invariant violation: \{context}",
        loc,
        source,
      )
    Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected~,
      got~,
      args~,
      loc~,
    ) =>
      make_render_error(
        "stage2-etale.template-arity-mismatch",
        "stage2-etale.expand",
        "template arity mismatch: template=\{template_name}, expected=\{expected}, got=\{got}, args=\{args}",
        loc,
        source,
      )
    Stage2EtaleError::NestedTemplateDefinitionInSubstitution(term~, loc~) =>
      make_render_error(
        "stage2-etale.nested-template-definition",
        "stage2-etale.expand",
        "nested template definition is not allowed in substitution: \{term}",
        loc,
        source,
      )
    Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(term~, loc~) =>
      make_render_error(
        "stage2-etale.unexpected-template-definition",
        "stage2-etale.expand",
        "unexpected template definition during expansion: \{term}",
        loc,
        source,
      )
    Stage3Error::AttributeExpectsAtMostOneValue(values~, loc~) =>
      make_render_error(
        "stage3.attribute-too-many-values",
        "stage3.lower",
        "attribute expects at most one value: \{values}",
        loc,
        source,
      )
    Stage3Error::UnexpectedTemplateDefinition(term~, loc~) =>
      make_render_error(
        "stage3.unexpected-template-definition",
        "stage3.lower",
        "unexpected template definition during lowering: \{term}",
        loc,
        source,
      )
    Failure::Failure(message) =>
      make_render_error("failure", "runtime", message, None, source)
    _ => make_render_error("unknown", "runtime", "\{err}", None, source)
  }
}

///|
fn render_error_to_string(err : RenderError) -> String {
  match err.loc {
    Some(loc) => "[\{err.phase}] \{loc.line}:\{loc.column}: \{err.message}"
    None => "[\{err.phase}] \{err.message}"
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
    err => Err([render_error(err, source)])
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
    err => Err([render_error(err, source)])
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
