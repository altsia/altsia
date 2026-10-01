///|
/// Splits one top-level equality into its left and right expression bodies.
/// Relation nodes nested inside groups remain part of the corresponding side.
pub fn split_equation(
  nodes : Array[@katex.ParseNode],
) -> (Array[@katex.ParseNode], Array[@katex.ParseNode]) raise EvalDiagnostic {
  let mut separator : Int? = None
  for i, node in nodes {
    match node {
      @katex.ParseNode::Atom(family=@katex.AtomFamily::Mrel, text="=", ..) =>
        match separator {
          None => separator = Some(i)
          Some(_) => raise EvalDiagnostic::make(InvalidEquation)
        }
      _ => ()
    }
  }
  match separator {
    None => raise EvalDiagnostic::make(InvalidEquation)
    Some(i) => {
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
  }
}
