///|
/// Coefficients supported by the generic sparse polynomial core.
pub trait PolynomialSemiring: Add + Mul + Eq {
  fn zero() -> Self
  fn one() -> Self
  fn is_zero(self : Self) -> Bool
}

///|
/// A coefficient system with additive inverses.
pub trait PolynomialRing: PolynomialSemiring + Neg {
  fn sub(self : Self, other : Self) -> Self
}

///|
pub impl PolynomialSemiring for Int with fn zero() -> Int {
  0
}

///|
pub impl PolynomialSemiring for Int with fn one() -> Int {
  1
}

///|
pub impl PolynomialSemiring for Int with fn is_zero(self : Int) -> Bool {
  self == 0
}

///|
pub impl PolynomialRing for Int with fn sub(self : Int, other : Int) -> Int {
  self - other
}
