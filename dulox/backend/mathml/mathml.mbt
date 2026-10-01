///|
/// Renders parsed KaTeX nodes as Presentation MathML.
pub fn render(
  nodes : Array[@katex.ParseNode],
  config? : RenderConfig = Default::default(),
) -> String {
  let state = {
    style: @katex.StyleLevel::TextStyle,
    math_variant: None,
    text_family: "normal",
    text_bold: false,
    text_italic: false,
    color: None,
  }
  let body = make_row(render_expression(nodes, state))

  // In the unicode backend, this is achieved by directly returning an empty string: 
  // Internal(..) | EnvironmentEnd(..) => ""
  guard !body.is_empty() else { return "" }

  let semantic_children = match config.annotation {
    Some(source) =>
      [
        body,
        element("annotation", children=[text_node(source)], attributes=[
          ("encoding", "application/x-tex"),
        ]),
      ]
    None => [body]
  }
  let math_attributes = [
    ("xmlns", "http://www.w3.org/1998/Math/MathML"),
    ..if config.display_mode {
      [("display", "block")]
    },
  ]
  element(
    "math",
    children=[element("semantics", children=semantic_children)],
    attributes=math_attributes,
  ).to_markup()
}

///|
fn render_expression(
  nodes : Array[@katex.ParseNode],
  state : RenderState,
) -> Array[MathMlNode] {
  combine_expression(nodes.map(node => render_node(node, state)))
}

///|
fn render_group(node : @katex.ParseNode, state : RenderState) -> MathMlNode {
  render_node(node, state)
}

///|
fn render_node(node : @katex.ParseNode, state : RenderState) -> MathMlNode {
  match node {
    Internal(..) | EnvironmentEnd(..) => element("mrow")
    Raw(string~, ..) => text_token(string, Text, state)
    ColorToken(color~, ..) => text_token(color, Text, state)
    AccentToken(text~, ..) | OperatorToken(text~, ..) =>
      token("mo", text, state)
    MathOrd(text~, ..) => token("mi", text, state)
    TextOrd(text~, mode~, ..) => text_ordinary(text, mode, state)
    Atom(text~, family~, ..) => render_atom(text, family, state)
    Spacing(text~, ..) => render_spacing(text)
    Size(value~, ..) =>
      element("mspace", attributes=[("width", measurement(value))])
    Url(url~, ..) => text_token(url, Text, state)
    Styling(body~, style~, reset_font~, ..) =>
      render_styling(body, style, reset_font, state)
    Text(body~, font~, ..) =>
      make_row(render_expression(body, text_state(font, state)))
    MClass(body~, mclass~, is_character_box~, ..) =>
      render_mclass(body, mclass, is_character_box, state)
    HBox(body~, ..) =>
      element(
        "mrow",
        children=render_expression(body, { ..state, math_variant: None, }),
      )
    Sizing(body~, size~, ..) =>
      element("mstyle", children=render_expression(body, state), attributes=[
        ("mathsize", size_multiplier(size)),
      ])
    Color(body~, color~, ..) =>
      element(
        "mstyle",
        children=render_expression(body, { ..state, color: Some(color), }),
        attributes=[("mathcolor", color)],
      )
    Href(body~, href~, ..) =>
      make_row(render_expression(body, state)).with_attribute("href", href)
    Html(body~, ..) | OrdGroup(body~, ..) =>
      make_row(render_expression(body, state))
    Sqrt(body~, index=None, ..) =>
      element("msqrt", children=[render_group(body, state)])
    Sqrt(body~, index=Some(index), ..) =>
      element("mroot", children=[
        render_group(body, state),
        render_group(index, state),
      ])
    Infix(replace_with~, ..) => token("mo", replace_with, state)
    GenFrac(
      numer~,
      denom~,
      has_bar_line~,
      bar_size~,
      left_delim~,
      right_delim~,
      ..
    ) =>
      render_fraction(
        numer, denom, has_bar_line, bar_size, left_delim, right_delim, state,
      )
    Font(font~, body~, ..) =>
      render_group(body, { ..state, math_variant: math_variant(font), })
    Op(content~, ..) => render_operator(content, state)
    OperatorName(body~, ..) => render_operator_name(body, state)
    Overline(body~, ..) => accent_over("mover", body, "‾", "accent", state)
    Underline(body~, ..) =>
      accent_over("munder", body, "‾", "accentunder", state)
    Smash(body~, smash_height~, smash_depth~, ..) => {
      let attrs = [
        ..if smash_height {
          [("height", "0px")]
        },
        ..if smash_depth {
          [("depth", "0px")]
        },
      ]
      element("mpadded", children=[render_group(body, state)], attributes=attrs)
    }
    VPhantom(body~, ..) =>
      element(
        "mpadded",
        children=[element("mphantom", children=[render_group(body, state)])],
        attributes=[("width", "0px")],
      )
    VCenter(body~, ..) =>
      element("mrow", children=[
        element("mpadded", children=[render_group(body, state)], attributes=[
          ("class", "vcenter"),
        ]),
      ])
    RaiseBox(dy~, body~, ..) =>
      element("mpadded", children=[render_group(body, state)], attributes=[
        ("voffset", measurement(dy)),
      ])
    Lap(alignment~, body~, ..) => render_lap(alignment, body, state)
    CdParent(fragment~, ..) =>
      element("mrow", children=[render_group(fragment, state)])
    Phantom(body~, ..) =>
      element("mphantom", children=render_expression(body, state))
    Pmb(body~, ..) =>
      element("mstyle", children=render_expression(body, state), attributes=[
        ("style", "text-shadow: 0.02em 0.01em 0.04px"),
      ])
    Rule(width~, height~, shift~, ..) =>
      render_rule(width, height, shift, state)
    MathChoice(display~, text~, script~, scriptscript~, ..) =>
      render_math_choice(display, text, script, scriptscript, state)
    HorizBrace(label~, is_over~, base~, ..) =>
      element(if is_over { "mover" } else { "munder" }, children=[
        render_group(base, state),
        stretchy(label),
      ])
    XArrow(label~, body~, below~, ..) =>
      render_xarrow(label, body, below, state)
    AccentUnder(label~, base~, ..) =>
      element("munder", children=[render_group(base, state), stretchy(label)], attributes=[
        ("accentunder", "true"),
      ])
    DelimSizing(delim~, mclass~, size~, ..) =>
      render_sized_delim(delim, mclass, size)
    LeftRightRight(delim~, color~, ..) => render_fence(delim, color)
    Middle(delim~, ..) => render_middle(delim)
    LeftRight(body~, left~, right~, right_color~, ..) =>
      render_left_right(body, left, right, right_color, state)
    Kern(dimension~, ..) =>
      element("mspace", attributes=[("width", measurement(dimension))])
    Enclose(label~, body~, background_color~, border_color~, ..) =>
      render_enclose(label, body, background_color, border_color, state)
    IncludeGraphics(alt~, width~, height~, totalheight~, src~, ..) =>
      render_image(alt, width, height, totalheight, src)
    Tag(body~, tag~, ..) => render_tag(body, tag, state)
    Array(
      body~,
      add_jot~,
      array_stretch~,
      columns~,
      row_gaps~,
      hlines_before_row~,
      column_separation_type~,
      tags~,
      auto_tags~,
      leqno~,
      ..
    ) =>
      render_array(
        body, columns, array_stretch, row_gaps, hlines_before_row, column_separation_type,
        tags, auto_tags, leqno, add_jot, state,
      )
    CdLabel(side~, label~, ..) => render_cd_label(side, label, state)
    Cr(new_line~, size~, ..) => render_cr(new_line, size)
    HtmlMathML(mathml~, ..) => make_row(render_expression(mathml, state))
    SupSub(base~, sup~, sub~, ..) => render_sup_sub(base, sup, sub, state)
    Accent(label~, is_stretchy~, base~, ..) =>
      render_accent(label, is_stretchy, base, state)
    Verb(body~, star~, ..) =>
      element("mtext", children=[text_node(verb_text(body, star))], attributes=[
        ("mathvariant", "monospace"),
      ])
  }
}
