///|
pub struct PaperMargins {
  top : String
  right : String
  bottom : String
  left : String
}

///|
priv struct ComputedPrintPaper {
  page_size : String
  margins : PaperMargins
  font_size : String
}

///|
priv struct ComputedScreenPaper {
  max_width : String
  padding : PaperMargins
  font_size : String
}

///|
priv struct ComputedPaper {
  print : ComputedPrintPaper
  screen : ComputedScreenPaper
}

///|
priv struct PrintPaperSlate {
  page_size : String
  margins : PaperMargins
  font_size : String
  staple_extra : String
}

///|
priv struct ScreenPaperSlate {
  max_width : String
  padding : PaperMargins
  font_size : String
}

///|
priv struct PaperSlate {
  print : PrintPaperSlate
  screen : ScreenPaperSlate
}

///|
pub(all) struct PaperOptions {
  slate_name : String
  staple : Bool
}

///|
pub const PAPER_CLASS_NAME : String = "paper"

///|
pub fn paper_style_css(
  options : PaperOptions,
  span : @core.SourceSpan,
) -> Result[String, @core.Diagnostic] {
  compute_paper(options, span).map(paper => {
    (
      $|
      $|@media screen {
      $|  .\{PAPER_CLASS_NAME} {
      $|    max-width: \{paper.screen.max_width};
      $|    margin: 0 auto;
      $|    padding: \{paper.screen.padding.css_box()};
      $|    box-sizing: border-box;
      $|    font-size: \{paper.screen.font_size};
      $|  }
      $|}
      $|
      $|@media print {
      $|  @page {
      $|    size: \{paper.print.page_size};
      $|    margin: \{paper.print.margins.css_box()};
      $|  }
      $|
      $|  .\{PAPER_CLASS_NAME} {
      $|    max-width: none;
      $|    margin: 0;
      $|    padding: 0;
      $|    box-sizing: border-box;
      $|    font-size: \{paper.print.font_size};
      $|  }
      $|}
      $|
    )
  })
}

///|
fn compute_paper(
  options : PaperOptions,
  span : @core.SourceSpan,
) -> Result[ComputedPaper, @core.Diagnostic] {
  match paper_slate_from_name(options.slate_name) {
    Some(slate) => Ok(slate.compute(options))
    None =>
      Err(
        span.diagnostic(
          @core.DiagnosticPhase::Type,
          "unknown paper slate: \{options.slate_name}",
        ),
      )
  }
}

///|
fn PaperSlate::compute(
  self : PaperSlate,
  options : PaperOptions,
) -> ComputedPaper {
  {
    print: {
      page_size: self.print.page_size,
      margins: self.print.margins.with_staple(
        options.staple,
        self.print.staple_extra,
      ),
      font_size: self.print.font_size,
    },
    screen: {
      max_width: self.screen.max_width,
      padding: self.screen.padding,
      font_size: self.screen.font_size,
    },
  }
}

///|
fn paper_slate_from_name(name : String) -> PaperSlate? {
  match name {
    "a4" =>
      Some({
        print: {
          page_size: "A4",
          margins: PaperMargins::same("24mm"),
          font_size: "11pt",
          staple_extra: "8mm",
        },
        screen: {
          max_width: "820px",
          padding: PaperMargins::same("32px"),
          font_size: "20px",
        },
      })
    "iso-b5" =>
      Some({
        print: {
          page_size: "176mm 250mm",
          margins: PaperMargins::same("18mm"),
          font_size: "10.5pt",
          staple_extra: "8mm",
        },
        screen: {
          max_width: "760px",
          padding: PaperMargins::same("28px"),
          font_size: "20px",
        },
      })
    "ebook" =>
      Some({
        print: {
          page_size: "152.4mm 228.6mm",
          margins: small_margins,
          staple_extra: "0mm",
          font_size: "11.5pt",
        },
        screen: {
          max_width: "820px",
          padding: PaperMargins::same("16px"),
          font_size: "20px",
        },
      })
    _ => None
  }
}

///|
fn PaperMargins::same(value : String) -> PaperMargins {
  { top: value, right: value, bottom: value, left: value }
}

///|
pub let small_margins : PaperMargins = PaperMargins::symmetry("4mm", "6mm")

///|
fn PaperMargins::symmetry(
  vertical : String,
  horizontal : String,
) -> PaperMargins {
  { top: vertical, right: horizontal, bottom: vertical, left: horizontal }
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
