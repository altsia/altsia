///|
/// Renders a symbolic solution as one or more condition-qualified cases.
pub fn solve_render(result : SolveResult) -> @katex.ParseNode {
  let body : Array[@katex.ParseNode] = []
  for index, case in result.cases {
    if index > 0 {
      body.append([
        Atom(mode=Math, loc=None, family=Mpunct, text=","),
        Kern(mode=Math, dimension={ number: 1, unit: "em", }),
      ])
    }
    body.append(render_case(result.variable, result.domain, case))
  }
  @katex.ParseNode::OrdGroup(
    mode=@katex.Mode::Math,
    loc=None,
    body~,
    semisimple=false,
  )
}

///|
fn render_case(
  variable : SymbolKey,
  domain : Domain,
  case : SolutionCase,
) -> Array[@katex.ParseNode] {
  let body : Array[@katex.ParseNode] = []
  match case.solution {
    Finite(roots) =>
      for index, root in roots {
        if index > 0 {
          body.push(comma)
        }
        body.push(render_equation(variable, index + 1, root))
      }
    Empty => body.push(emptyset)
    Universal => body.push(domain.display())
  }

  guard case.conditions.length() > 0 else { body }

  let conditions = case.conditions[1:]
    .map(c => c.render_condition())
    .fold(init=[case.conditions[0].render_condition()], (a, b) => {
      [..a, Atom(mode=Math, loc=None, family=Mpunct, text=","), b]
    })

  body.append(
    [
      space,
      Atom(mode=Math, loc=None, family=Mopen, text="("),
      ..conditions,
      Atom(mode=Math, loc=None, family=Mclose, text=")"),
    ],
  )
  body
}

///|
fn render_equation(
  variable : SymbolKey,
  index : Int,
  root : EvalExpr,
) -> @katex.ParseNode {
  OrdGroup(
    mode=Math,
    loc=None,
    body=[
      SupSub(
        mode=Math,
        base=Some(MathOrd(mode=Math, loc=None, text=variable.text)),
        sup=None,
        sub=Some(MathOrd(mode=Math, loc=None, text=index.to_string())),
      ),
      Atom(mode=Math, loc=None, family=Mrel, text="="),
      render_root(root),
    ],
    semisimple=false,
  )
}

///|
fn render_root(expr : EvalExpr) -> @katex.ParseNode {
  render(expr).unwrap_or(unknown)
}

///|
fn Condition::render_condition(cond : Condition) -> @katex.ParseNode {
  match cond {
    Zero(expr) => render_relation(expr, "=")
    NonZero(expr) => render_relation(expr, "≠")
    NonNegative(expr) => render_relation(expr, "≥")
  }
}

///|
fn render_relation(expr : EvalExpr, op : String) -> @katex.ParseNode {
  OrdGroup(
    mode=Math,
    loc=None,
    body=[
      render_root(expr),
      Atom(mode=Math, loc=None, family=Mrel, text=op),
      render_root(zero),
    ],
    semisimple=false,
  )
}
