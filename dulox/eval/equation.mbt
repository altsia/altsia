///|
/// Splits one top-level equality into its left and right expression bodies.
/// Relation nodes nested inside groups remain part of the corresponding side.
pub fn split_equation(
  nodes : Array[@katex.ParseNode],
) -> (Array[@katex.ParseNode], Array[@katex.ParseNode]) raise EvalDiagnostic {
  let mut separator : Int? = None
  for i, node in nodes {
    guard node
      is @katex.ParseNode::Atom(family=@katex.AtomFamily::Mrel, text="=", ..) else {
      continue
    }
    guard separator is None else { raise EvalDiagnostic::make(InvalidEquation) }
    separator = Some(i)
  }
  guard separator is Some(i) else {
    raise EvalDiagnostic::make(InvalidEquation)
  }
  let lhs : Array[@katex.ParseNode] = []
  let rhs : Array[@katex.ParseNode] = []
  for j in 0..<i {
    lhs.push(nodes[j])
  }
  for j in (i + 1)..<nodes.length() {
    rhs.push(nodes[j])
  }
  guard lhs.length() > 0 && rhs.length() > 0 else {
    raise EvalDiagnostic::make(InvalidEquation)
  }
  (lhs, rhs)
}
