///|
/// Resolves a TeX symbol name (or a raw Unicode string) to its Unicode
/// rendering via the parser's public registry, then applies math escaping.
fn render_symbol(text : String) -> String {
  escape_math(@backend.resolve_symbol(text))
}

///|
fn render_op(content : @katex.OperatorContent, state : RenderState) -> String {
  match content {
    SymbolOperator(text) => render_symbol(text)
    NamedOperator(text) => render_named_operator(text)
    BodyOperator(body) => "op(\{wrap_arg(render_nodes(body, state))})"
  }
}

///|
/// Typst predefines these operator names; emitting the bare name gives proper
/// limit placement in display mode. Others fall back to `op("...")`.
let typst_operator_names : Set[String] = Set([
  "arccos", "arcsin", "arctan", "arg", "cos", "cosh", "cot", "coth", "csc", "csch",
  "ctg", "deg", "det", "dim", "exp", "gcd", "hom", "id", "im", "inf", "ker", "lg",
  "lim", "liminf", "limsup", "ln", "log", "max", "min", "mod", "Pr", "sec", "sech",
  "sin", "sinc", "sinh", "sup", "tan", "tanh", "tg", "tr", "lcm",
])

///|
fn render_named_operator(text : String) -> String {
  let name = @backend.command_name(text)
  if typst_operator_names.contains(name) {
    name
  } else {
    "op(\"\{escape_string(name)}\")"
  }
}

///|
fn render_operatorname(
  body : Array[@katex.ParseNode],
  limits : Bool,
  state : RenderState,
) -> String {
  let text = plain_text_of(body)
  let content = text.map_or(wrap_arg(render_nodes(body, state)), quote_string)
  let limits_arg = if limits { ", limits: #true" } else { "" }
  "op(\{content}\{limits_arg})"
}

///|
/// Collects the plain text of a list of purely textual nodes (text ordinals
/// and spaces), or `None` if it contains any math structure. Parts are joined
/// without separators; the result is always embedded in a quoted string, so
/// spaces are preserved verbatim.
fn plain_text_of(nodes : Array[@katex.ParseNode]) -> String? {
  let parts : Array[String] = nodes.filter_map(node => {
    match node {
      TextOrd(text~, ..) | MathOrd(text~, ..) | Spacing(text~, ..) =>
        Some(@backend.resolve_symbol(text))
      _ => None
    }
  })
  guard parts.length() == nodes.length() else { None }
  Some(parts.join(""))
}
