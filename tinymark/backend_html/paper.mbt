///|
pub struct PaperSpecification {
  page_size : String
  width : String
  margins : PaperMargins
  font_size : String
}

///|
pub struct PaperMargins {
  top : String
  right : String
  bottom : String
  left : String
}

///|
priv struct PaperPreset {
  page_size : String
  width : String
  margins : PaperMargins
  staple_extra : String
  font_size : String
}

///|
fn paper_spec_from_name(
  name : String,
  span : SourceSpan,
  staple~ : Bool,
) -> Result[PaperSpecification, Diagnostic] {
  match paper_preset_from_name(name) {
    Some(preset) =>
      Ok({
        page_size: preset.page_size,
        width: preset.width,
        margins: preset.margins.with_staple(staple, preset.staple_extra),
        font_size: preset.font_size,
      })
    _ =>
      Err(
        span.diagnostic(DiagnosticPhase::Type, "unknown paper preset: \{name}"),
      )
  }
}

///|
fn paper_body_style(spec : PaperSpecification) -> String {
  "max-width: \{spec.width}; margin: 0 auto; padding: \{spec.margins.css_box()}; box-sizing: border-box; font-size: \{spec.font_size}"
}

///|
fn paper_print_style(spec : PaperSpecification) -> HtmlNode {
  HtmlNode::Element("style", [], [
    HtmlNode::RawHtml(
      "@media print { @page { size: \{spec.page_size}; margin: \{spec.margins.css_box()}; } }",
    ),
  ])
}

///|
fn paper_preset_from_name(name : String) -> PaperPreset? {
  match name {
    "a4" =>
      Some({
        page_size: "A4",
        width: "210mm",
        margins: PaperMargins::same("24mm"),
        staple_extra: "8mm",
        font_size: "11pt",
      })
    "iso-b5" =>
      Some({
        page_size: "176mm 250mm",
        width: "176mm",
        margins: PaperMargins::same("18mm"),
        staple_extra: "8mm",
        font_size: "10.5pt",
      })
    _ => None
  }
}

///|
fn PaperMargins::same(value : String) -> PaperMargins {
  { top: value, right: value, bottom: value, left: value }
}

///|
fn PaperMargins::with_staple(
  self : PaperMargins,
  staple : Bool,
  extra : String,
) -> PaperMargins {
  guard staple else { self }
  { ..self, left: "calc(\{self.left} + \{extra})" }
}

///|
fn PaperMargins::css_box(self : PaperMargins) -> String {
  "\{self.top} \{self.right} \{self.bottom} \{self.left}"
}
