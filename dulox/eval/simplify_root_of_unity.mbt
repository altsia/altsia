///|
/// Returns the canonical integer parameters of a concrete root of unity. A
/// root of unity is only defined for integral order and power; symbolic values
/// are left opaque so that later evaluation can establish those constraints.
fn concrete_root_of_unity(
  order : EvalExpr,
  power : EvalExpr,
) -> (Int, Int)? raise EvalDiagnostic {
  let order = exact_integer(order)
  let power = exact_integer(power)
  guard (order, power) is (Some(order), Some(power)) else { return None }
  guard order > 0 else { raise EvalDiagnostic::make(InvalidPower) }
  let reduced = positive_mod(power, order)
  guard reduced != 0 else { return Some((order, 0)) }
  let divisor = gcd_int(order, reduced)
  Some((order / divisor, reduced / divisor))
}

///|
fn simplify_root_of_unity(
  order : EvalExpr,
  power : EvalExpr,
) -> EvalExpr raise EvalDiagnostic {
  guard !(order is Rational(value) &&
    value.denominator() != @bigint.BigInt::from_int(1)) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard !(power is Rational(value) &&
    value.denominator() != @bigint.BigInt::from_int(1)) else {
    raise EvalDiagnostic::make(InvalidPower)
  }
  guard concrete_root_of_unity(order, power) is Some((order, power)) else {
    return RootOfUnity(order~, power~)
  }
  guard order != 1 && power != 0 else { one }
  guard !(order == 2 && power == 1) else { Integer(-1) }
  RootOfUnity(order=Integer(order), power=Integer(power))
}

///|
/// Owns product-factor order while merging concrete roots with the same order.
/// Symbolic roots and all other factors remain in their original positions.
priv struct UnitRootCollector {
  factors : Array[EvalExpr]
}

///|
fn UnitRootCollector::make() -> UnitRootCollector {
  { factors: [], }
}

///|
fn UnitRootCollector::add(
  self : UnitRootCollector,
  factor : EvalExpr,
) -> Unit raise EvalDiagnostic {
  match factor {
    RootOfUnity(order=Integer(order), power=Integer(power)) =>
      self.add_concrete_root(order, power, factor)
    _ => self.factors.push(factor)
  }
}

///|
/// Retains both factors if their powers cannot be added exactly.
fn UnitRootCollector::add_concrete_root(
  self : UnitRootCollector,
  order : Int,
  power : Int,
  root : EvalExpr,
) -> Unit raise EvalDiagnostic {
  for i in 0..<self.factors.length() {
    match self.factors[i] {
      RootOfUnity(order=Integer(existing_order), power=Integer(existing_power)) if existing_order ==
        order => {
        guard checked_int_add(existing_power, power) is Some(merged_power) else {
          self.factors.push(root)
          return
        }
        self.factors[i] = simplify_root_of_unity(
          Integer(order),
          Integer(merged_power),
        )
        return
      }
      _ => ()
    }
  }
  self.factors.push(root)
}

///|
fn UnitRootCollector::finish(self : UnitRootCollector) -> Array[EvalExpr] {
  self.factors
}

///|
/// Combines concrete unit-root factors of the same order before ordinary
/// numeric multiplication handles the rest of the product.
fn simplify_unit_root_factors(
  children : Array[EvalExpr],
) -> Array[EvalExpr] raise EvalDiagnostic {
  let collector = UnitRootCollector::make()
  for child in children {
    match child {
      RootOfUnity(order~, power~) => {
        let root = simplify_root_of_unity(order, power)
        if root != one {
          collector.add(root)
        }
      }
      _ => collector.add(child)
    }
  }
  collector.finish()
}
