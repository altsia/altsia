///|
/// Renders a computed expression back into a `@katex.ParseNode`, inserting grouping
/// and parentheses according to operator precedence
/// (`Add < Mul < Div < Pow < Atom`).
pub fn render(expr : EvalExpr) -> Result[@katex.ParseNode, EvalDiagnostic] {
  Ok(render_expr(expr, 0))
}

///|
fn precedence(expr : EvalExpr) -> Int {
  match expr {
    Add(_) | Complex(_, _) => 1
    Mul(_) => 2
    Div(_, _) => 3
    IntPow(_, _) | Pow(_, _) | Root(_) => 4
    _ => 5
  }
}

///|
fn render_expr(expr : EvalExpr, parent_prec : Int) -> @katex.ParseNode {
  let prec = precedence(expr)
  let node = match expr {
    Integer(value) => render_number(value)
    Rational(value) => render_rational(value)
    Symbol(symbol) =>
      @katex.ParseNode::MathOrd(
        mode=@katex.Mode::Math,
        loc=None,
        text=symbol.text,
      )
    Add(children) => render_add(children)
    Mul(children) => render_mul(children)
    IntPow(base, exp) => render_pow(base, exp)
    Pow(base, exponent) => render_general_pow(base, exponent)
    Div(numer, denom) =>
      @katex.ParseNode::GenFrac(
        mode=@katex.Mode::Math,
        numer=render_expr(numer, 3),
        denom=render_expr(denom, 3),
        continued=false,
        has_bar_line=true,
        bar_size=None,
        left_delim=None,
        right_delim=None,
      )
    Root(index~, radicand) =>
      @katex.ParseNode::Sqrt(
        mode=@katex.Mode::Math,
        body=render_expr(radicand, 0),
        index=if index == two { None } else { Some(render_expr(index, 0)) },
      )
    RootOfUnity(order~, power~) => render_root_of_unity(order, power)
    Complex(re, im) => render_complex(re, im)
    Residual(node) => node
  }
  if prec < parent_prec {
    @katex.ParseNode::OrdGroup(
      mode=@katex.Mode::Math,
      loc=None,
      body=[node],
      semisimple=false,
    )
  } else {
    node
  }
}

///|
fn render_rational(value : @rational.BigRational) -> @katex.ParseNode {
  guard value.denominator() != @bigint.BigInt::from_int(1) else {
    return render_integer_text(value.numerator().to_string())
  }
  @katex.ParseNode::GenFrac(
    mode=@katex.Mode::Math,
    numer=render_integer_text(value.numerator().to_string()),
    denom=render_integer_text(value.denominator().to_string()),
    continued=false,
    has_bar_line=true,
    bar_size=None,
    left_delim=None,
    right_delim=None,
  )
}

///|
fn render_integer_text(text : String) -> @katex.ParseNode {
  @katex.ParseNode::MathOrd(mode=@katex.Mode::Math, loc=None, text~)
}

///|
fn render_root_of_unity(order : EvalExpr, power : EvalExpr) -> @katex.ParseNode {
  let base = match order {
    Integer(3) =>
      @katex.ParseNode::MathOrd(mode=@katex.Mode::Math, loc=None, text="ω")
    _ => @katex.ParseNode::MathOrd(mode=@katex.Mode::Math, loc=None, text="ζ")
  }
  let base = match order {
    Integer(3) => base
    _ =>
      @katex.ParseNode::SupSub(
        mode=@katex.Mode::Math,
        base=Some(base),
        sup=None,
        sub=Some(render_expr(order, 0)),
      )
  }
  guard power != one else { base }
  @katex.ParseNode::SupSub(
    mode=@katex.Mode::Math,
    base=Some(base),
    sup=Some(render_expr(power, 0)),
    sub=None,
  )
}

///|
fn render_add(children : Array[EvalExpr]) -> @katex.ParseNode {
  let body : Array[@katex.ParseNode] = []
  let mut first = true
  for child in children {
    let (sign, magnitude) = split_sign(child)
    if first {
      if sign < 0 {
        body.push(minus)
        body.push(render_expr(magnitude, 2))
      } else {
        body.push(render_expr(magnitude, 2))
      }
      first = false
    } else {
      body.push(if sign < 0 { minus } else { plus })
      body.push(render_expr(magnitude, 2))
    }
  }
  @katex.ParseNode::OrdGroup(
    mode=@katex.Mode::Math,
    loc=None,
    body~,
    semisimple=false,
  )
}

///|
/// Extracts the sign of an addition term, leaving a non-negative magnitude.
fn split_sign(expr : EvalExpr) -> (Int, EvalExpr) {
  match expr {
    Integer(value) if value < 0 => (-1, Integer(-value))
    Mul(children) if children.length() > 0 =>
      match children[0] {
        Integer(coefficient) if coefficient < 0 => {
          let rest : Array[EvalExpr] = [Integer(-coefficient)]
          for i in 1..<children.length() {
            rest.push(children[i])
          }
          (-1, Mul(rest))
        }
        _ => (1, expr)
      }
    _ => (1, expr)
  }
}

///|
fn render_mul(children : Array[EvalExpr]) -> @katex.ParseNode {
  let body : Array[@katex.ParseNode] = []
  let mut first = true
  for child in children {
    match child {
      Integer(coefficient) if coefficient == 1 => ()
      Integer(coefficient) if coefficient == -1 && first => body.push(minus)
      Integer(coefficient) if coefficient < 0 && first => {
        body.push(minus)
        body.push(render_expr(Integer(-coefficient), 3))
      }
      _ => body.push(render_expr(child, 3))
    }
    first = false
  }
  @katex.ParseNode::OrdGroup(
    mode=@katex.Mode::Math,
    loc=None,
    body~,
    semisimple=false,
  )
}

///|
fn render_pow(base : EvalExpr, exp : Int) -> @katex.ParseNode {
  let base_node = render_expr(base, 4)
  let base_node = match base {
    Integer(value) if value < 0 =>
      @katex.ParseNode::OrdGroup(
        mode=@katex.Mode::Math,
        loc=None,
        body=[base_node],
        semisimple=false,
      )
    _ => base_node
  }
  @katex.ParseNode::SupSub(
    mode=@katex.Mode::Math,
    base=Some(base_node),
    sup=Some(render_exponent(exp)),
    sub=None,
  )
}

///|
fn render_general_pow(base : EvalExpr, exponent : EvalExpr) -> @katex.ParseNode {
  let base_node = render_expr(base, 4)
  let base_node = match base {
    Integer(value) if value < 0 =>
      @katex.ParseNode::OrdGroup(
        mode=@katex.Mode::Math,
        loc=None,
        body=[base_node],
        semisimple=false,
      )
    _ => base_node
  }
  @katex.ParseNode::SupSub(
    mode=@katex.Mode::Math,
    base=Some(base_node),
    sup=Some(render_expr(exponent, 0)),
    sub=None,
  )
}

///|
fn render_exponent(exp : Int) -> @katex.ParseNode {
  if exp >= 0 {
    @katex.ParseNode::MathOrd(
      mode=@katex.Mode::Math,
      loc=None,
      text=exp.to_string(),
    )
  } else {
    @katex.ParseNode::OrdGroup(
      mode=@katex.Mode::Math,
      loc=None,
      body=[
        minus,
        @katex.ParseNode::MathOrd(
          mode=@katex.Mode::Math,
          loc=None,
          text=(-exp).to_string(),
        ),
      ],
      semisimple=false,
    )
  }
}

///|
fn render_number(value : Int) -> @katex.ParseNode {
  if value < 0 {
    return @katex.ParseNode::OrdGroup(
      mode=@katex.Mode::Math,
      loc=None,
      body=[minus, render_number(-value)],
      semisimple=false,
    )
  }
  @katex.ParseNode::MathOrd(
    mode=@katex.Mode::Math,
    loc=None,
    text=value.to_string(),
  )
}

///|
/// Renders the canonical complex node `re + im·i` as `re ± |im|·i`, folding
/// zero real/imaginary parts away.
fn render_complex(re : EvalExpr, im : EvalExpr) -> @katex.ParseNode {
  // #[degeneration]
  guard re != zero else { return render_imag_part(im) }
  guard im != zero else { return render_expr(re, 0) }

  let (im_sign, im_mag) = split_sign(im)
  @katex.ParseNode::OrdGroup(
    mode=@katex.Mode::Math,
    loc=None,
    body=[
      render_expr(re, 2),
      if im_sign < 0 {
        minus
      } else {
        plus
      },
      render_imag_part(im_mag),
    ],
    semisimple=false,
  )
}

///|
fn render_imag_part(mag : EvalExpr) -> @katex.ParseNode {
  let (sign, mag) = split_sign(mag)

  let magnitude = {
    guard mag != one else { image_unit }
    @katex.ParseNode::OrdGroup(
      mode=@katex.Mode::Math,
      loc=None,
      body=[render_expr(mag, 3), image_unit],
      semisimple=false,
    )
  }

  guard sign < 0 else { return magnitude }
  @katex.ParseNode::OrdGroup(
    mode=@katex.Mode::Math,
    loc=None,
    body=[minus, magnitude],
    semisimple=false,
  )
}
