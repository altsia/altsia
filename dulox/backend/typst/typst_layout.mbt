///|
fn render_styling(
  body : Array[@katex.ParseNode],
  style : @katex.StyleLevel,
) -> String {
  let state = { style, }
  match style {
    // Text style is the default; only a `\tfrac`-style fraction needs an
    // explicit `inline(...)`.
    TextStyle if body is [GenFrac(..)] =>
      math_fn("inline", render_nodes(body, state))
    TextStyle => render_nodes(body, state)
    _ => render_style_wrapper(style, wrap_arg(render_nodes(body, state)))
  }
}

///|
/// Wraps rendered content in the display/script-level Typst function; empty
/// content renders as nothing rather than an empty call.
fn render_style_wrapper(style : @katex.StyleLevel, content : String) -> String {
  guard content != "" else { "" }
  match style {
    DisplayStyle => "display(\{content})"
    ScriptStyle => "script(\{content})"
    ScriptScriptStyle => "sscript(\{content})"
    TextStyle => content
  }
}

///|
fn render_sizing(
  size : Int,
  body : Array[@katex.ParseNode],
  state : RenderState,
) -> String {
  let em = @backend.katex_size_multiplier(size)
  "text(size: #\{em}em, \{render_nodes(body, state)})"
}

///|
fn render_sup_sub(
  base : @katex.ParseNode?,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  state : RenderState,
) -> String {
  let sup_mark = script_marks('^', sup, state)
  let sub_mark = script_marks('_', sub, state)
  guard base is Some(node) else { return "zws\{sup_mark}\{sub_mark}" }
  match node {
    @katex.ParseNode::HorizBrace(label~, base=brace_base, ..) =>
      render_folded_brace(label, brace_base, sup, sub, state)
    @katex.ParseNode::XArrow(label~, body~, below~, ..) =>
      render_folded_arrow(label, body, below, sup, sub, state)
    // `\dddot`/`\ddddot` expand to
    // `\overset{\raisebox{-0.1ex}{\normalsize ...}}{x}`; recognize that
    // shape and emit the native dot accents instead of the generic
    // `attach` fallback.
    @katex.ParseNode::Op(
      content=@katex.OperatorContent::BodyOperator(body),
      limits=true,
      ..
    ) if sup.map_or(None, dddot_dots) is Some(count) =>
      "accent(\{wrap_arg(render_nodes(body, state))}, \{dddot_symbol(count)})"
    @katex.ParseNode::Op(
      content=@katex.OperatorContent::BodyOperator(_),
      limits=true,
      ..
    ) => render_sup_attach(node, sup, sub, state)
    @katex.ParseNode::OperatorName(limits=true, ..) =>
      render_sup_attach(node, sup, sub, state)
    _ => "\{render_node(node, state)}\{sup_mark}\{sub_mark}"
  }
}

///|
/// `\overset`/`\underset`/`\operatorname*` attach their scripts as limits
/// above/below the operator. `limits(...)` is required: a plain `attach`
/// would only place the scripts next to the base without limit placement.
fn render_sup_attach(
  base : @katex.ParseNode,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  state : RenderState,
) -> String {
  "limits(\{render_node(base, state)})\{script_marks('^', sup, state)}\{script_marks('_', sub, state)}"
}

///|
/// Renders a `^`/`_` script marker with its content, wrapping the content in
/// parentheses when it needs grouping (see `wrap_script`).
fn script_marks(
  mark : Char,
  node : @katex.ParseNode?,
  state : RenderState,
) -> String {
  node.map_or("", node => "\{mark}\{wrap_script(render_node(node, state))}")
}

///|
/// Script operands may be wrapped in parentheses: Typst strips them in `^`/`_`
/// position, so they are a safe way to group content containing separators or
/// multiple items (a top-level space means the operand spans several atoms and
/// would otherwise bind only the first one).
fn wrap_script(content : String) -> String {
  if contains_script_separator(content) {
    "(\{content})"
  } else {
    content
  }
}

///|
fn contains_script_separator(text : String) -> Bool {
  contains_top_level_char(text, is_script_separator)
}

///|
fn is_script_separator(c : Char) -> Bool {
  c == ' ' ||
  c == '=' ||
  c == ',' ||
  c == ';' ||
  c == ':' ||
  c == '^' ||
  c == '_'
}

///|
/// `\overbrace{x}^{label}` folds into `attach(overbrace(x), t: label)` since
/// Typst attaches the label relative to the brace.
fn render_folded_brace(
  label : String,
  body : @katex.ParseNode,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  state : RenderState,
) -> String {
  let brace = horiz_brace_name(label)
  "attach(\{brace}(\{wrap_arg(render_node(body, state))})\{attach_arg("t", sup, state)}\{attach_arg("b", sub, state)})"
}

///|
/// Renders an `attach(...)` named argument (`, t: ...` / `, b: ...`) when the
/// node is present, or nothing.
fn attach_arg(
  name : String,
  node : @katex.ParseNode?,
  state : RenderState,
) -> String {
  node.map_or("", node => ", \{name}: \{wrap_arg(render_node(node, state))}")
}

///|
fn render_folded_arrow(
  label : String,
  body : @katex.ParseNode,
  below : @katex.ParseNode?,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
  state : RenderState,
) -> String {
  let arrow = xarrow_name(label)
  let body_str = wrap_arg(render_node(body, state))
  // A present `sup` takes over the top label; the xarrow's own label moves
  // to `t:`.
  let t_str = sup.map_or(body_str, node => {
    "\{wrap_arg(render_node(node, state))}, t: \{body_str}"
  })
  let b_str = match below {
    Some(_) => attach_arg("b", below, state)
    None => attach_arg("b", sub, state)
  }
  "attach(\{arrow}, t: \{t_str}\{b_str})"
}

///|
fn render_genfrac(
  numer : @katex.ParseNode,
  denom : @katex.ParseNode,
  has_bar_line : Bool,
  left_delim : String?,
  right_delim : String?,
  state : RenderState,
) -> String {
  let num = wrap_frac(render_node(numer, state))
  let den = wrap_frac(render_node(denom, state))
  let frac = "\{num} / \{den}"
  if is_binomial_genfrac(has_bar_line, left_delim, right_delim) {
    "binom(\{num}, \{den})"
  } else if is_delimited_genfrac(has_bar_line, left_delim, right_delim) {
    render_delimited(frac, left_delim, right_delim)
  } else {
    frac
  }
}

///|
/// A `\genfrac` without a bar line and with both delimiters renders as
/// Typst's `binom`.
fn is_binomial_genfrac(
  has_bar_line : Bool,
  left_delim : String?,
  right_delim : String?,
) -> Bool {
  !has_bar_line && left_delim is Some(_) && right_delim is Some(_)
}

///|
/// A `\genfrac` whose delimiters cannot fold into `binom` still needs
/// explicit delimiters around the fraction.
fn is_delimited_genfrac(
  has_bar_line : Bool,
  left_delim : String?,
  right_delim : String?,
) -> Bool {
  (has_bar_line && left_delim is Some(_)) || right_delim is Some(_)
}

///|
/// Typst's `/` is the fraction operator; numerator/denominator containing a
/// top-level `+`/`-`/space (i.e. multiple atoms) need parentheses, since
/// `a + 1 / b` would parse as `a + (1/b)`.
fn wrap_frac(content : String) -> String {
  if contains_top_level_frac_op(content) {
    "(\{content})"
  } else {
    content
  }
}

///|
fn contains_top_level_frac_op(text : String) -> Bool {
  contains_top_level_char(text, is_frac_separator)
}

///|
fn is_frac_separator(c : Char) -> Bool {
  c == ' ' || c == '+' || c == '-' || c == '='
}

///|
/// Wraps content in the given delimiters using a fixed-size `lr`. Used for
/// `\genfrac` with delimiters, which has no direct Typst equivalent.
fn render_delimited(
  content : String,
  left_delim : String?,
  right_delim : String?,
) -> String {
  let l = left_delim.map_or("", render_lr_delim)
  let r = right_delim.map_or("", render_lr_delim)
  guard l != "" || r != "" else { content }
  lr_single_side(content, l, r)
}

///|
fn render_spacing(text : String) -> String {
  match text {
    "\\nobreak" | "\\allowbreak" => ""
    _ => " "
  }
}

///|
fn render_kern(dimension : @katex.Measurement) -> String {
  let amount = match @backend.em_value(dimension) {
    Some(em) if dimension.unit == "mu" => em_string(em)
    _ =>
      if dimension.unit == "fill" {
        "1fr"
      } else {
        render_measurement(dimension)
      }
  }
  "#h(\{amount})"
}
