///|
/// Print CSS for the paper size, e.g. an `@page` rule. Empty for plain
/// documents.
fn print_css(paper : @parsing.Paper) -> String {
  match paper {
    @parsing.Paper::A4 =>
      [
        css_at_block("page", [("size", "A4"), ("margin", "25mm")]),
        css_media("print", [css_rule("body", [("font-size", "12pt")])]),
      ].join("\n")
    @parsing.Paper::B5 =>
      [
        css_at_block("page", [("size", "182mm 257mm"), ("margin", "20mm")]),
        css_media("print", [css_rule("body", [("font-size", "11pt")])]),
      ].join("\n")
    @parsing.Paper::Book =>
      [
        css_at_block("page", [
          ("size", "142mm 205mm"),
          ("margin", small_margins_66.css_box()),
        ]),
        css_media("print", [css_rule("body", [("font-size", "12pt")])]),
      ].join("\n")
  }
}
