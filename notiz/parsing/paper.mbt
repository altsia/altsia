///|
/// The paper size of a rendered document, also usable as a builtin
/// frontmatter attribute.
pub(all) enum Paper {
  A4
  B5
  Book
} derive(Eq, Debug)

///|
pub extend Paper with Eq::{not_equal, equal}

///|
pub extend Paper with Debug::{to_repr}

///|
/// The known paper sizes by name, in declaration order.
let paper_sizes : Map[String, Paper] = { "a4": A4, "b5": B5, "book": Book }

///|
pub fn Paper::from_string(name : String) -> Result[Paper, String] {
  match paper_sizes.get(name) {
    Some(paper) => Ok(paper)
    None => Err("unknown paper size: \{name}")
  }
}

///|
pub fn Paper::names() -> Iter[String] {
  paper_sizes.keys()
}
