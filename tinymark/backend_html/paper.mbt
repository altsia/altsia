///|
pub struct PaperSpecification {
  page_size : String
  width : String
  margin : String
  font_size : String
}

///|
fn paper_spec(
  doc_attrs : Array[Attr],
  env : CompileEnv,
) -> Result[PaperSpecification?, Diagnostic] {
  for attr in doc_attrs {
    guard attr.name == "paper" else { continue }
    guard attr.value is Some(value) else {
      return Err(
        attr.span.diagnostic(DiagnosticPhase::Type, "paper requires a value"),
      )
    }
    match value_to_scalar(value, env) {
      Ok(name) => return paper_spec_by_name(name, attr.span)
      Err(error) => return Err(error)
    }
  }
  Ok(None)
}

///|
fn paper_spec_by_name(
  name : String,
  span : SourceSpan,
) -> Result[PaperSpecification?, Diagnostic] {
  match name {
    "a4" =>
      Ok(
        Some({
          page_size: "A4",
          width: "210mm",
          margin: "24mm",
          font_size: "11pt",
        }),
      )
    "iso-b5" =>
      Ok(
        Some({
          page_size: "176mm 250mm",
          width: "176mm",
          margin: "18mm",
          font_size: "10.5pt",
        }),
      )
    _ =>
      Err(
        span.diagnostic(DiagnosticPhase::Type, "unknown paper preset: " + name),
      )
  }
}

///|
fn paper_body_style(spec : PaperSpecification) -> String {
  "max-width: \{spec.width}; margin: \{spec.margin} auto; font-size: \{spec.font_size}"
}

///|
fn paper_print_style(spec : PaperSpecification) -> HtmlNode {
  HtmlNode::Element("style", [], [
    HtmlNode::RawHtml(
      "@media print { @page { size: \{spec.page_size}; margin: \{spec.margin}; } }",
    ),
  ])
}
