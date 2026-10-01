///|
pub struct PaperMargins {
  top : String
  right : String
  bottom : String
  left : String
}

///|
pub let small_margins_46 : PaperMargins = PaperMargins::symmetry("4mm", "6mm")

///|
pub let small_margins_66 : PaperMargins = PaperMargins::same("6mm")

///|
pub fn PaperMargins::same(value : String) -> PaperMargins {
  { top: value, right: value, bottom: value, left: value, }
}

///|
pub fn PaperMargins::symmetry(
  vertical : String,
  horizontal : String,
) -> PaperMargins {
  { top: vertical, right: horizontal, bottom: vertical, left: horizontal, }
}

///|
pub fn PaperMargins::with_staple(
  self : PaperMargins,
  staple : Bool,
  extra : String,
) -> PaperMargins {
  guard staple else { self }
  { ..self, left: "calc(\{self.left} + \{extra})", }
}

///|
pub fn PaperMargins::css_box(self : PaperMargins) -> String {
  "\{self.top} \{self.right} \{self.bottom} \{self.left}"
}
