///|
/// Renders parsed KaTeX nodes back to KaTeX source. Because the parser already
/// expands macros and resolves symbols, the output is the fully expanded,
/// canonical form of the input: `\def\foo{x}\foo` renders as `x`, and
/// `\dfrac{a}{b}` renders as `\displaystyle\frac{a}{b}`. The output re-parses
/// to an equivalent AST.
pub fn render(nodes : Array[@katex.ParseNode]) -> String {
  render_nodes(nodes)
}

///|
fn render_nodes(nodes : Array[@katex.ParseNode]) -> String {
  join_math(nodes.map(node => render_node(node)))
}

///|
/// Renders a single node. Symbol and token text is emitted verbatim; every
/// structured node is emitted as the KaTeX construct it encodes.
fn render_node(node : @katex.ParseNode) -> String {
  match node {
    Internal(..) | EnvironmentEnd(..) => ""
    Raw(string~, ..) => string
    ColorToken(color~, ..) => "\\color{\{color}}"
    MathOrd(text~, ..)
    | TextOrd(text~, ..)
    | OperatorToken(text~, ..)
    | AccentToken(text~, ..) => render_symbol_text(text)
    Atom(text~, ..) => render_symbol_text(text)
    Spacing(text~, ..) => render_spacing(text)
    Size(value~, is_blank~, ..) => render_size(value, is_blank)
    Url(url~, ..) => "\\url{\{url}}"
    Styling(body~, style~, mode~, ..) => render_styling(mode, body, style)
    Sqrt(body~, index~, ..) => render_sqrt(index, body)
    Infix(replace_with~, ..) => render_infix(replace_with)
    GenFrac(
      numer~,
      denom~,
      continued~,
      has_bar_line~,
      bar_size~,
      left_delim~,
      right_delim~,
      ..
    ) =>
      render_genfrac(
        render_arg(numer),
        render_arg(denom),
        continued,
        has_bar_line,
        bar_size,
        left_delim,
        right_delim,
      )
    Text(body~, font~, ..) => render_text(body, font)
    Font(font~, body~, ..) => render_font(font, body)
    MClass(mclass~, body~, ..) => render_mclass(mclass, body)
    Op(content~, limits~, ..) => render_op(content, limits)
    OperatorName(body~, always_handle_sup_sub~, ..) =>
      render_operator_name(body, always_handle_sup_sub)
    Overline(body~, ..) => "\\overline{\{render_arg(body)}}"
    Underline(body~, ..) => "\\underline{\{render_arg(body)}}"
    Smash(body~, smash_height~, smash_depth~, ..) =>
      render_smash(body, smash_height, smash_depth)
    Phantom(body~, ..) => "\\phantom{\{render_nodes(body)}}"
    VPhantom(body~, ..) => "\\vphantom{\{render_arg(body)}}"
    Pmb(body~, ..) => "\\pmb{\{render_nodes(body)}}"
    VCenter(body~, ..) => "\\vcenter{\{render_arg(body)}}"
    Rule(width~, height~, shift~, ..) => render_rule(width, height, shift)
    RaiseBox(dy~, body~, ..) =>
      "\\raisebox{\{render_measurement(dy)}}{\{render_arg(body)}}"
    HBox(body~, ..) => "\\hbox{\{render_nodes(body)}}"
    Lap(alignment~, body~, ..) => render_lap(alignment, body)
    MathChoice(display~, text~, script~, scriptscript~, ..) =>
      "\\mathchoice{\{render_nodes(display)}}{\{render_nodes(text)}}{\{render_nodes(script)}}{\{render_nodes(scriptscript)}}"
    Sizing(size~, body~, ..) => render_sizing(size, body)
    HorizBrace(label~, is_over~, base~, ..) =>
      render_horiz_brace(label, is_over, base)
    XArrow(label~, body~, below~, ..) => render_xarrow(label, body, below)
    AccentUnder(label~, base~, ..) => "\{label}{\{render_arg(base)}}"
    DelimSizing(size~, mclass~, delim~, ..) =>
      render_delim_sizing(size, mclass, delim)
    LeftRightRight(delim~, ..) => "\\right\{render_delimiter(delim)}"
    LeftRight(body~, left~, right~, ..) => render_left_right(body, left, right)
    Middle(delim~, ..) => "\\middle\{render_delimiter(delim)}"
    Kern(dimension~, ..) => render_kern(dimension)
    Enclose(label~, body~, background_color~, border_color~, ..) =>
      render_enclose(label, body, background_color, border_color)
    Href(href~, body~, ..) => "\\href{\{href}}{\{render_nodes(body)}}"
    Html(attributes~, body~, ..) => render_html(attributes, body)
    IncludeGraphics(width~, height~, src~, ..) =>
      render_includegraphics(width, height, src)
    Tag(body~, tag~, ..) => render_tag(body, tag)
    Array(..) => render_array(node)
    CdLabel(..) | CdParent(..) | Cr(..) => render_cd_internal(node)
    HtmlMathML(html~, ..) =>
      // `\html@mathml{html}{mathml}` carries a MathML-output fallback in its
      // second argument (often a `\char` of a glyph that re-expands as a macro,
      // e.g. `\ne`). For source output only the `html` argument renders, so it
      // is emitted alone.
      render_nodes(html)
    OrdGroup(body~, ..) => braced(render_nodes(body))
    SupSub(base~, sup~, sub~, ..) => render_sup_sub(base, sup, sub)
    Accent(label~, base~, ..) => "\{label}{\{render_arg(base)}}"
    Verb(body~, star~, ..) => render_verb(body, star)
    Color(color~, body~, ..) => render_color(color, body)
  }
}

///|
/// Renders a braced function argument: a single `OrdGroup` (the way a `{...}`
/// argument parses) is unwrapped, since the function's own braces reproduce
/// the group. Any other node renders directly.
fn render_arg(node : @katex.ParseNode) -> String {
  match node {
    @katex.ParseNode::OrdGroup(body~, ..) => render_nodes(body)
    _ => render_node(node)
  }
}

///|
fn render_spacing(text : String) -> String {
  match text {
    "\\nobreak" | "\\allowbreak" => ""
    _ => text
  }
}

///|
/// `\hskip`-style sizes (from `\quad`, `\enspace`, ...) are emitted back as
/// an explicit `\hskip`. A blank (`\hspace*`-style) size emits the bare
/// command.
fn render_size(value : @katex.Measurement, is_blank : Bool) -> String {
  if is_blank {
    "\\hskip"
  } else {
    "\\hskip{\{render_measurement(value)}}"
  }
}

///|
fn render_sqrt(index : @katex.ParseNode?, body : @katex.ParseNode) -> String {
  guard index is Some(index) else { return "\\sqrt{\{render_arg(body)}}" }
  "\\sqrt[\{render_arg(index)}]{\{render_arg(body)}}"
}

///|
/// `\over`/`\atop`/`\choose` infix markers are consumed into `GenFrac` by the
/// parser; a stray marker has no faithful emission and renders as nothing.
fn render_infix(replace_with : String) -> String {
  let _ = replace_with
  ""
}

///|
/// A style command takes the rest of the current group as its body, so it is
/// emitted unbraced (the parser's `parse_expression` reads exactly that
/// suffix). A style-wrapped `\genfrac` folds into the dedicated commands
/// (`\dfrac`, `\tfrac`, `\cfrac`, `\dbinom`, `\tbinom`). A body of the form
/// `[OrdGroup(...)]` (the shape of array cells and `\hbox`-style arguments)
/// emits its content braced, and a nested style is collapsed so re-parsing
/// inside an environment stays idempotent.
fn render_styling(
  mode : @katex.Mode,
  body : Array[@katex.ParseNode],
  style : @katex.StyleLevel,
) -> String {
  let command = style_command(style)
  match body {
    [
      @katex.ParseNode::GenFrac(
        numer~,
        denom~,
        continued~,
        has_bar_line~,
        bar_size~,
        left_delim~,
        right_delim~,
        ..
      ),
    ] =>
      render_styled_genfrac(
        style, numer, denom, continued, has_bar_line, bar_size, left_delim, right_delim,
      )
    [
      @katex.ParseNode::Styling(
        mode=inner_mode,
        body=inner_body,
        style=inner_style,
        ..
      ),
    ] if style == inner_style =>
      render_styling(inner_mode, inner_body, inner_style)
    [
      @katex.ParseNode::OrdGroup(
        body=[
          @katex.ParseNode::Styling(
            mode=inner_mode,
            body=inner_body,
            style=inner_style,
            ..
          ),
        ],
        ..
      ),
    ] => render_styling(inner_mode, inner_body, inner_style)
    [@katex.ParseNode::OrdGroup(body=inner_body, ..)] =>
      "\{command}{\{render_style_body(mode, inner_body)}}"
    _ => "\{command} \{render_style_body(mode, body)}"
  }
}

///|
fn render_style_body(
  mode : @katex.Mode,
  body : Array[@katex.ParseNode],
) -> String {
  if mode == @katex.Mode::Text {
    join_tight(body.map(node => render_node(node)))
  } else {
    render_nodes(body)
  }
}

///|
fn style_command(style : @katex.StyleLevel) -> String {
  match style {
    @katex.StyleLevel::DisplayStyle => "\\displaystyle"
    @katex.StyleLevel::TextStyle => "\\textstyle"
    @katex.StyleLevel::ScriptStyle => "\\scriptstyle"
    @katex.StyleLevel::ScriptScriptStyle => "\\scriptscriptstyle"
  }
}

///|
fn render_measurement(measurement : @katex.Measurement) -> String {
  "\{measurement.number}\{measurement.unit}"
}

///|
fn render_smash(
  body : @katex.ParseNode,
  smash_height : Bool,
  smash_depth : Bool,
) -> String {
  match (smash_height, smash_depth) {
    (true, true) => "\\smash{\{render_arg(body)}}"
    (true, false) => "\\smash[t]{\{render_arg(body)}}"
    (false, true) => "\\smash[b]{\{render_arg(body)}}"
    (false, false) => "\\smash{\{render_arg(body)}}"
  }
}

///|
fn render_rule(
  width : @katex.Measurement,
  height : @katex.Measurement,
  shift : @katex.Measurement?,
) -> String {
  let shift = shift.map_or("", value => "[\{render_measurement(value)}]")
  "\\rule\{shift}{\{render_measurement(width)}}{\{render_measurement(height)}}"
}

///|
fn render_lap(
  alignment : @katex.LapAlignment,
  body : @katex.ParseNode,
) -> String {
  let (plain, wrapped) = match alignment {
    @katex.LapAlignment::LLap => ("\\mathllap", "\\llap")
    @katex.LapAlignment::RLap => ("\\mathrlap", "\\rlap")
    @katex.LapAlignment::CLap => ("\\mathclap", "\\clap")
  }
  // `\llap`/`\rlap`/`\clap` expand to `\math...lap{\textrm{#1}}`; emitting the
  // unwrapped body under the `\llap` family name keeps the `\textrm` from
  // being duplicated on re-parse.
  match body {
    @katex.ParseNode::Text(body=nodes, ..) =>
      "\{wrapped}{\{join_tight(nodes.map(render_node))}}"
    _ => "\{plain}{\{render_arg(body)}}"
  }
}

///|
fn render_sizing(size : Int, body : Array[@katex.ParseNode]) -> String {
  let commands = [
    "\\tiny", "\\sixptsize", "\\scriptsize", "\\footnotesize", "\\small", "\\normalsize",
    "\\large", "\\Large", "\\LARGE", "\\huge", "\\Huge",
  ]
  let command = commands.get(size - 1).unwrap_or("\\normalsize")
  "\{command}{\{render_size_body(body)}}"
}

///|
/// Unwraps a single `OrdGroup` body (the shape of a braced `\large{x}`) so the
/// command's own braces reproduce the group.
fn render_size_body(body : Array[@katex.ParseNode]) -> String {
  match body {
    [@katex.ParseNode::OrdGroup(body=inner, ..)] => render_nodes(inner)
    _ => render_nodes(body)
  }
}

///|
fn render_sup_sub(
  base : @katex.ParseNode?,
  sup : @katex.ParseNode?,
  sub : @katex.ParseNode?,
) -> String {
  let base = base.map_or("{}", node => {
    if base_needs_brace(node) {
      braced(render_node(node))
    } else {
      render_node(node)
    }
  })
  "\{base}\{script_mark("^", sup)}\{script_mark("_", sub)}"
}

///|
/// A script operand needs explicit braces when it is not a single bare
/// character token: a bare `x^a^b` would parse as a double script, and a
/// multi-character operand would bind only its first atom.
fn script_mark(mark : String, node : @katex.ParseNode?) -> String {
  node.map_or("", node => {
    if script_needs_brace(node) {
      "\{mark}{\{render_node(node)}}"
    } else {
      "\{mark}\{render_node(node)}"
    }
  })
}

///|
/// A bare token renders as a single unit; an `OrdGroup` is already braced and
/// serves as the script operand's group. Everything else needs explicit braces
/// so the script binds the whole construct.
fn script_needs_brace(node : @katex.ParseNode) -> Bool {
  match node {
    MathOrd(text~, ..)
    | TextOrd(text~, ..)
    | Atom(text~, ..)
    | OperatorToken(text~, ..)
    | AccentToken(text~, ..) => text.length() != 1
    OrdGroup(..) => false
    _ => true
  }
}

///|
/// A base needs braces when a following script would otherwise attach to its
/// last atom instead of the whole construct: a fraction would grab the
/// denominator, and a nested script would form a double script.
fn base_needs_brace(node : @katex.ParseNode) -> Bool {
  match node {
    GenFrac(..) | SupSub(..) => true
    MathOrd(text~, ..)
    | TextOrd(text~, ..)
    | Atom(text~, ..)
    | OperatorToken(text~, ..)
    | AccentToken(text~, ..) => text.length() != 1
    OrdGroup(..) => false
    _ => false
  }
}

///|
fn render_verb(body : String, star : Bool) -> String {
  let star = if star { "*" } else { "" }
  "\\verb\{star}\{verb_delimiter(body)}\{body}\{verb_delimiter(body)}"
}

///|
/// Picks a delimiter character not present in the verb body.
fn verb_delimiter(body : String) -> Char {
  let candidates = ['|', '!', '+', ':', ';', '"', '\'', '#', '%', '&']
  for candidate in candidates {
    guard !body.contains(String::from_array([candidate])) else { continue }
    return candidate
  }
  '|'
}

///|
fn render_color(color : String, body : Array[@katex.ParseNode]) -> String {
  "\\color{\{color}}\{render_nodes(body)}"
}

///|
/// `\tag{...}` sets `\df@tag` to `\text{(#1)}` (parens for the plain form,
/// none for `\tag*`), so the stored tag is a `\text` node wrapping the user
/// argument. Emitting `\tag{arg}` / `\tag*{arg}` with the unwrapped argument
/// lets the macro reproduce it. A tag body that re-parses as a single display
/// style is collapsed (the display mode that produced the tag re-applies it).
fn render_tag(
  body : Array[@katex.ParseNode],
  tag : Array[@katex.ParseNode],
) -> String {
  let body = match body {
    [@katex.ParseNode::Styling(body=inner, ..)] => render_nodes(inner)
    _ => render_nodes(body)
  }
  let body = if body == "" { "" } else { "\{body} " }
  "\{body}\{render_tag_content(tag)}"
}

///|
fn render_tag_content(tag : Array[@katex.ParseNode]) -> String {
  match tag {
    [
      @katex.ParseNode::Text(
        body=[
          @katex.ParseNode::TextOrd(text="(", ..),
          ..,
          @katex.ParseNode::TextOrd(text=")", ..),
        ],
        ..
      ),
    ] => "\\tag{\{join_tight(tag_inner(tag).map(render_arg))}}"
    [@katex.ParseNode::Text(body=[only], ..)] => "\\tag*{\{render_arg(only)}}"
    _ => "\\tag{\{render_nodes(tag)}}"
  }
}

///|
/// The middle of a parenthesized tag (`\text{(...)}`), i.e. the nodes between
/// the opening and closing parenthesis.
fn tag_inner(tag : Array[@katex.ParseNode]) -> Array[@katex.ParseNode] {
  match tag {
    [
      @katex.ParseNode::Text(
        body=[
          @katex.ParseNode::TextOrd(text="(", ..),
          ..,
          @katex.ParseNode::TextOrd(text=")", ..),
        ],
        ..
      ),
    ] =>
      match tag[0] {
        @katex.ParseNode::Text(body~, ..) =>
          body.exact_view(start=1, end=body.length() - 1).to_owned()
        _ => []
      }
    _ => []
  }
}

///|
/// Symbol text is emitted verbatim: the parser keeps the original token, so a
/// `\alpha` MathOrd emits back `\alpha` (identical re-parse), and a literal
/// character (`+`, `5`, `α` typed directly) is already safe KaTeX source.
/// Characters the parser only produces via `\char` (a lone combining mark, or
/// any code point the lexer does not accept as a regular character) cannot be
/// typed literally and are re-emitted through `\char`.
fn render_symbol_text(text : String) -> String {
  guard needs_char_escape(text) else { text }
  char_command(text)
}

///|
/// A literal character needs `\char` re-emission when it does not survive a
/// literal round trip: a leading combining diacritical mark has no base to
/// attach to, and a lone surrogate, a lone backslash (a `\char"5c` artifact),
/// or a non-regular code unit is not lexable. Text starting with `\` is a
/// command token (always re-lexable) only when longer than the backslash
/// itself.
fn needs_char_escape(text : String) -> Bool {
  guard !text.is_empty() else { false }
  guard !(text.has_prefix("\\") && text.length() > 1) else { return false }
  let first = text[0]
  is_combining_mark_code(first) ||
  is_surrogate_code(first) ||
  !is_regular_code(first)
}

///|
/// The combining diacritical mark range (U+0300..U+036F), matching the
/// parser's lexer.
fn is_combining_mark_code(c : UInt16) -> Bool {
  c >= 0x300 && c <= 0x36f
}

///|
fn is_surrogate_code(c : UInt16) -> Bool {
  (c >= 0xd800 && c <= 0xdbff) || (c >= 0xdc00 && c <= 0xdfff)
}

///|
/// The lexer's accepted "regular" code unit range.
fn is_regular_code(c : UInt16) -> Bool {
  (c >= 0x21 && c <= 0x5b) ||
  (c >= 0x5d && c <= 0x2027) ||
  (c >= 0x202a && c <= 0xd7ff) ||
  (c >= 0xf900 && c <= 0xffff)
}

///|
/// Re-emits an un-typeable character as `\char"HEX`. The escaped cases are
/// single BMP code units, so the first code unit's value is the code point.
fn char_command(text : String) -> String {
  let code = text[0].to_int()
  "\\char\"\{code.to_string(radix=16)}"
}
