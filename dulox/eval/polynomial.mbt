///|
pub struct Term[E] {
  exps : Array[Int]
  coeff : E
} derive(Debug)

///|
pub extend Term with Debug::{to_repr}

///|
/// A sparse polynomial whose axes may be symbols or opaque evaluator
/// expressions. Each term's exponent vector is indexed by `axes`.
pub struct Polynomial[E] {
  axes : Array[MonomialFactor]
  terms : @hashmap.HashMap[String, Term[E]]
} derive(Debug)

///|
pub extend Polynomial with Debug::{to_repr}

///|
pub extend Polynomial with Neg::{neg}

///|
pub extend Polynomial with Add::{add}

///|
pub extend Polynomial with Sub::{sub}

///|
pub extend Polynomial with Mul::{mul}

///|
fn algebra_monomial_key(exps : Array[Int]) -> String {
  exps.map(exp => exp.to_string()).join(",")
}

///|
fn algebra_axes_from_symbols(symbols : Array[String]) -> Array[MonomialFactor] {
  let axes : Array[MonomialFactor] = []
  for symbol in symbols {
    axes.push(SymbolFactor(SymbolKey::make(symbol)))
  }
  axes
}

///|
fn algebra_sort_axes(axes : Array[MonomialFactor]) -> Array[MonomialFactor] {
  let sorted = axes
  sorted.sort_by((left, right) => {
    compare_canonical_strings(
      left.to_canonical_string(),
      right.to_canonical_string(),
    )
  })
  sorted
}

///|
fn[E : PolynomialSemiring] algebra_add_term(
  terms : @hashmap.HashMap[String, Term[E]],
  exps : Array[Int],
  coeff : E,
) -> Unit {
  guard !coeff.is_zero() else { return }
  let key = algebra_monomial_key(exps)
  match terms.get(key) {
    Some(term) => {
      let new_coeff = term.coeff + coeff
      if new_coeff.is_zero() {
        terms.remove(key)
      } else {
        terms[key] = Term::{ exps: term.exps, coeff: new_coeff, }
      }
    }
    None => terms[key] = Term::{ exps, coeff, }
  }
}

///|
fn algebra_axes_equal(
  left : Array[MonomialFactor],
  right : Array[MonomialFactor],
) -> Bool {
  guard left.length() == right.length() else { false }
  for i in 0..<left.length() {
    guard left[i] == right[i] else { return false }
  }
  true
}

///|
fn[E] algebra_align_to_axes(
  poly : Polynomial[E],
  new_axes : Array[MonomialFactor],
) -> Polynomial[E] {
  let index_map = algebra_axis_indices(poly.axes, new_axes)
  let terms = @hashmap.HashMap([])
  for _, term in poly.terms {
    let exps = algebra_relocate_exponents(
      term.exps,
      index_map,
      new_axes.length(),
    )
    terms[algebra_monomial_key(exps)] = Term::{ exps, coeff: term.coeff, }
  }
  Polynomial::{ axes: new_axes, terms, }
}

///|
fn algebra_axis_indices(
  old_axes : Array[MonomialFactor],
  new_axes : Array[MonomialFactor],
) -> Array[Int] {
  old_axes.map(axis => algebra_find_axis(new_axes, axis))
}

///|
fn algebra_find_axis(
  axes : Array[MonomialFactor],
  axis : MonomialFactor,
) -> Int {
  for i, candidate in axes {
    if candidate == axis {
      return i
    }
  }
  axes.length()
}

///|
fn algebra_relocate_exponents(
  exps : Array[Int],
  index_map : Array[Int],
  width : Int,
) -> Array[Int] {
  let relocated = Array::makei(width, _ => 0)
  for i in 0..<index_map.length() {
    relocated[index_map[i]] = exps[i]
  }
  relocated
}

///|
fn[E] algebra_align(
  a : Polynomial[E],
  b : Polynomial[E],
) -> (Polynomial[E], Polynomial[E]) {
  let axes = a.axes.copy()
  for axis in b.axes {
    guard !axes.contains(axis) else { continue }
    axes.push(axis)
  }
  let axes = algebra_sort_axes(axes)
  (algebra_align_to_axes(a, axes), algebra_align_to_axes(b, axes))
}

///|
fn[E] algebra_zero_with_axes(axes : Array[MonomialFactor]) -> Polynomial[E] {
  Polynomial::{ axes, terms: @hashmap.HashMap([]), }
}

///|
fn[E : PolynomialSemiring] algebra_from_factor_term(
  axes : Array[MonomialFactor],
  exps : Array[Int],
  coeff : E,
) -> Polynomial[E] {
  let terms = @hashmap.HashMap([])
  algebra_add_term(terms, exps, coeff)
  Polynomial::{ axes, terms, }
}

///|
pub fn[E] Polynomial::zero(symbols : Array[String]) -> Polynomial[E] {
  algebra_zero_with_axes(algebra_axes_from_symbols(symbols))
}

///|
pub fn[E : PolynomialSemiring] Polynomial::one(
  symbols : Array[String],
) -> Polynomial[E] {
  Polynomial::from_term(
    symbols,
    Array::makei(symbols.length(), _ => 0),
    E::one(),
  )
}

///|
pub fn[E : PolynomialSemiring] Polynomial::from_term(
  symbols : Array[String],
  exps : Array[Int],
  coeff : E,
) -> Polynomial[E] {
  algebra_from_factor_term(algebra_axes_from_symbols(symbols), exps, coeff)
}

///|
pub fn[E : PolynomialSemiring] Polynomial::from_constant(
  symbols : Array[String],
  coeff : E,
) -> Polynomial[E] {
  Polynomial::from_term(symbols, Array::makei(symbols.length(), _ => 0), coeff)
}

///|
pub fn[E : PolynomialSemiring] Polynomial::coeff(
  poly : Polynomial[E],
  exps : Array[Int],
) -> E {
  match poly.terms.get(algebra_monomial_key(exps)) {
    Some(term) => term.coeff
    None => E::zero()
  }
}

///|
pub impl[E : PolynomialSemiring] Add for Polynomial[E] with fn add(a, b) {
  let (a, b) = if algebra_axes_equal(a.axes, b.axes) {
    (a, b)
  } else {
    algebra_align(a, b)
  }
  let terms = @hashmap.HashMap([])
  for _, term in a.terms {
    algebra_add_term(terms, term.exps, term.coeff)
  }
  for _, term in b.terms {
    algebra_add_term(terms, term.exps, term.coeff)
  }
  Polynomial::{ axes: a.axes, terms, }
}

///|
pub impl[E : PolynomialSemiring + Neg] Neg for Polynomial[E] with fn neg(self) {
  let terms = @hashmap.HashMap([])
  for _, term in self.terms {
    algebra_add_term(terms, term.exps, -term.coeff)
  }
  Polynomial::{ axes: self.axes, terms, }
}

///|
pub impl[E : PolynomialRing] Sub for Polynomial[E] with fn sub(a, b) {
  a + -b
}

///|
pub impl[E : PolynomialSemiring] Mul for Polynomial[E] with fn mul(a, b) {
  let (a, b) = if algebra_axes_equal(a.axes, b.axes) {
    (a, b)
  } else {
    algebra_align(a, b)
  }
  let terms = @hashmap.HashMap([])
  for _, left in a.terms {
    for _, right in b.terms {
      let exps = algebra_add_exponents(left.exps, right.exps)
      algebra_add_term(terms, exps, left.coeff * right.coeff)
    }
  }
  Polynomial::{ axes: a.axes, terms, }
}

///|
fn algebra_add_exponents(left : Array[Int], right : Array[Int]) -> Array[Int] {
  Array::makei(left.length(), i => left[i] + right[i])
}

///|
pub fn[E] Polynomial::variables(self : Polynomial[E]) -> Array[String] {
  let variables : Array[String] = []
  for axis in self.axes {
    match axis {
      SymbolFactor(symbol) => variables.push(symbol.text)
      OpaqueFactor(_) => ()
    }
  }
  variables
}

///|
fn algebra_find_symbol_axis(
  axes : Array[MonomialFactor],
  variable : String,
) -> Int? {
  for i, axis in axes {
    match axis {
      SymbolFactor(symbol) => if symbol.text == variable { return Some(i) }
      OpaqueFactor(_) => ()
    }
  }
  None
}

///|
/// Projects a multivariate polynomial onto one symbol. Each returned item is
/// the coefficient polynomial for one power of `variable`.
pub fn[E : PolynomialSemiring] Polynomial::coefficients_in(
  self : Polynomial[E],
  variable : String,
) -> Array[Polynomial[E]] raise EvalDiagnostic {
  guard algebra_find_symbol_axis(self.axes, variable) is Some(target) else {
    raise EvalDiagnostic::make(NoVariable)
  }
  let remaining_axes : Array[MonomialFactor] = []
  for i, axis in self.axes {
    if i != target {
      remaining_axes.push(axis)
    }
  }
  let mut degree = 0
  for _, term in self.terms {
    if term.exps[target] > degree {
      degree = term.exps[target]
    }
  }
  let result = Array::makei(degree + 1, _ => {
    algebra_zero_with_axes(remaining_axes.copy())
  })
  for _, term in self.terms {
    let exps : Array[Int] = []
    for i in 0..<term.exps.length() {
      if i != target {
        exps.push(term.exps[i])
      }
    }
    let coefficient = algebra_from_factor_term(
      remaining_axes.copy(),
      exps,
      term.coeff,
    )
    result[term.exps[target]] = result[term.exps[target]] + coefficient
  }
  result
}

///|
/// Raises a sparse polynomial to a non-negative integer power using binary
/// exponentiation.
pub fn[E : PolynomialSemiring] Polynomial::pow(
  self : Polynomial[E],
  exp : Int,
) -> Polynomial[E] {
  let unit_exps = Array::makei(self.axes.length(), _ => 0)
  guard exp > 0 else {
    algebra_from_factor_term(self.axes, unit_exps, E::one())
  }
  let mut result = algebra_from_factor_term(
    self.axes.copy(),
    unit_exps,
    E::one(),
  )
  let mut base = self
  let mut n = exp
  while n > 0 {
    if n % 2 == 1 {
      result = result * base
    }
    n = n / 2
    if n > 0 {
      base = base * base
    }
  }
  result
}

///|
