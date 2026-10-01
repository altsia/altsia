///|
/// ax³ + bx² + cx + d = 0
fn cubic_equation(
  variable : SymbolKey,
  a : EvalExpr,
  b : EvalExpr,
  c : EvalExpr,
  d : EvalExpr,
  domain : Domain,
  assumptions : Array[Condition],
  allow_degenerate~ : Bool,
) -> SolveResult raise EvalDiagnostic {

  // If this polynomial has a rational root, then it is a reducible polynomial over Q. 
  if a is Integer(int_a) &&
    b is Integer(int_b) &&
    c is Integer(int_c) &&
    d is Integer(int_d) {
    let coeffs = [int_d, int_c, int_b, int_a].map(BigInt::from_int)
    let (int_b, int_a) = (coeffs[2], coeffs[3])
    let rational_roots = (@pythagoras.rational_root_candidates(coeffs) catch {
      _error => raise EvalDiagnostic::make(EvalFailureKind::TriviallyAll)
    }).filter(r => @pythagoras.is_root(coeffs, r))

    if rational_roots.length() > 0 {
      let rat_r = rational_roots[0]
      let r = Rational(rat_r)

      // ax³ + bx² + cx + d = a(x-r)(x-s)(x-t), r is a rational root, s and t are the other two roots. We can find s and t by solving the quadratic equation. 
      //   r + s + t = -b/a ⟹ s + t = -b/a - r
      //   r ⋅ s ⋅ t = -d/a ⟹ s ⋅ t = -d/(a ⋅ r)
      //
      // x² - (s + t)x + s ⋅ t = 0 
      //   ⟹ x² + (b/a + r)x - d/(a ⋅ r) = 0
      //   ⟹ ax² + (b + a ⋅ r)x + (- d/r) = 0

      let discriminant = EvalExpr::simplify_solve(
        Pow(
          Rational(
            @rational.new(int_b, 1).unwrap() +
            @rational.new(int_a, 1).unwrap() * rat_r,
          ),
          two,
        ) +
        Mul([Integer(4), a, d / r]),
        domain,
      )
      let quadratic_result = quadratic_solution(
        a,
        b + a * r,
        discriminant,
        domain,
      )

      return SolveResult::{
        variable,
        domain,
        cases: [
          SolutionCase::{
            conditions: [],
            solution: Finite([r]).merge(quadratic_result),
          },
        ],
      }
    }
  }

  let cases : Array[SolutionCase] = []

  // a ≠ 0
  if conditions_are_possible([NonZero(a)], assumptions) {
    let conditions : Array[Condition] = [NonZero(a)]

    // Δ₀ = b² - 3ac
    let delta0 = (IntPow(b, 2) - Mul([Integer(3), a, c])).simplify_solve(domain)

    // Δ₁ = 2b³ - 9abc + 27a²d
    let delta1 = (Mul([two, IntPow(b, 3)]) -
    Mul([Integer(9), a, b, c]) +
    Mul([Integer(27), IntPow(a, 2), d])).simplify_solve(domain)

    let d = (IntPow(delta1, 2) - Mul([Integer(4), IntPow(delta0, 3)])).simplify_solve(
      domain,
    )

    cases.push(SolutionCase::{
      conditions: prune_conditions(conditions, assumptions),
      solution: cubic_solution(a, b, delta0, delta1, d, domain),
    })
  }

  // a = 0, #[degeneration]
  if allow_degenerate && conditions_are_possible([Zero(a)], assumptions) {
    let quadratic = quadratic_equation(
      variable,
      b,
      c,
      d,
      domain,
      assumptions,
      allow_degenerate~,
    )
    quadratic.cases.each(c => {
      push_conditioned_case(cases, Zero(a), c, assumptions)
    })
  }

  SolveResult::{ variable, domain, cases, }
}

///|
pub let omega_1 : EvalExpr = RootOfUnity(order=three, power=one)

///|
pub let omega_2 : EvalExpr = RootOfUnity(order=three, power=two)

///|
pub let omega_3 : EvalExpr = RootOfUnity(order=three, power=three)

///|
fn cubic_solution(
  a : EvalExpr,
  b : EvalExpr,
  delta0 : EvalExpr,
  delta1 : EvalExpr,
  d : EvalExpr,
  domain : Domain,
) -> SolutionKind raise EvalDiagnostic {
  let c = ({
    guard delta0 != zero else { cbrt(delta1) }
    cbrt((delta1 + sqrt(d)) / two)
  }).simplify_solve(domain)

  let x1 = -(b + c + delta0 / c) / (three * a) // a ≠ 0
  let x2 = -(b + c * omega_1 + delta0 * omega_2 / c) / (three * a)
  let x3 = -(b + c * omega_2 + delta0 * omega_1 / c) / (three * a)
  Finite([x1, x2, x3].map(x => x.simplify_solve(domain)))
}
