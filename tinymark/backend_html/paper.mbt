///|
pub struct PaperSpecification {
  page_size : String
  width : String
  margin : String
  font_size : String
}

///|
fn paper_spec_from_name(
  name : String,
  span : SourceSpan,
) -> Result[PaperSpecification, Diagnostic] {
  match name {
    "a4" =>
      Ok({ page_size: "A4", width: "210mm", margin: "24mm", font_size: "11pt" })
    "iso-b5" =>
      Ok({
        page_size: "176mm 250mm",
        width: "176mm",
        margin: "18mm",
        font_size: "10.5pt",
      })
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
