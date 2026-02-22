///|
pub(all) struct Taxon {
  numbering : String?
  text : String
}

///|
pub fn Taxon::display(self : Taxon) -> String {
  guard self.numbering is Some(numbering) else { self.text }
  self.text + numbering
}
