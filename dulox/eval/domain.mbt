///|
/// The ambient number system for solving. `Real` forbids imaginary results and
/// emits a `NonNegative(discriminant)` condition for symbolic discriminants;
/// `Complex` folds `sqrt` of negatives into `Complex` nodes.
pub(all) enum Domain {
  // Z
  // Fp
  // Q
  R
  // Qp
  C
} derive(Eq, Debug)

///|
pub fn Domain::display(domain : Domain) -> @katex.ParseNode {
  match domain {
    R => reals
    C => complex_numbers
  }
}
