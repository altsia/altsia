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
pub impl PolynomialSemiring for Int32 with fn zero() -> Int32 {
  0
}

///|
pub impl PolynomialSemiring for Int32 with fn one() -> Int32 {
  1
}

///|
pub impl PolynomialSemiring for Int32 with fn is_zero(self : Int32) -> Bool {
  self == 0
}

///|
pub impl PolynomialRing for Int32 with fn sub(self : Int32, other : Int32) -> Int32 {
  self - other
}
