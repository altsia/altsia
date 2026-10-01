///|
fn render_left_right(
  body : Array[@katex.ParseNode],
  left : String,
  right : String,
  state : RenderState,
) -> String {
  match body {
    [array] if array is @katex.ParseNode::Array(..) =>
      render_leftright_array(array, left, right, state)
    _ => wrap_lr(render_nodes(body, state), left, right)
  }
}

///|
/// Wraps rendered content in the given delimiters: both visible → `lr(...)`;
/// a single visible side → fixed-size `lr` next to the content; none → the
/// bare content.
fn wrap_lr(content : String, left : String, right : String) -> String {
  let l = render_lr_delim(left)
  let r = render_lr_delim(right)
  if l != "" && r != "" {
    "lr(\{l} \{content} \{r})"
  } else if l != "" || r != "" {
    lr_single_side(content, l, r)
  } else {
    content
  }
}

///|
/// A fixed-size `lr` placed after the content for a single visible
/// delimiter; shared with `render_delimited`.
fn lr_single_side(content : String, l : String, r : String) -> String {
  "\{content} lr(size: #2em, \{if l == "" { r } else { l }})"
}

///|
fn render_delim_sizing(size : Int, delim : String) -> String {
  // KaTeX `\big`..`\Bigg` carry sizes 1..4, indexing the em table 0-based.
  let sizes = [1.2, 1.8, 2.4, 3.0]
  let em = sizes.get(size - 1).unwrap_or(1.2)
  "lr(size: #\{em}em, \{render_lr_delim(delim)})"
}

///|
/// Renders a delimiter outside of an `lr` wrapper (e.g. `\right` alone).
fn render_delimiter(delim : String) -> String {
  guard !@backend.is_null_delimiter(delim) else { "" }
  render_symbol(delim)
}

///|
/// Renders a delimiter as `lr(...)` content: `(` `)` `[` `]` and `{` `}` are
/// escaped with a backslash since a bare one would open a brace group.
fn render_lr_delim(delim : String) -> String {
  guard !@backend.is_null_delimiter(delim) else { "" }
  match delim {
    "(" => "\\("
    ")" => "\\)"
    "[" => "\\["
    "]" => "\\]"
    "{" | "\\{" => "\\{"
    "}" | "\\}" => "\\}"
    _ => render_symbol(delim)
  }
}
