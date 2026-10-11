///|
fn render_extra_node(node : @katex.ParseNode, options : Options) -> HtmlNode? {
  Some(
    match node {
      Phantom(body~, ..) =>
        make_fragment(
          build_expression(
            body,
            { ..options, phantom: true, },
            real_group=false,
          ),
        )
      VPhantom(body~, ..) => {
        let inner = make_span(["katex-inner"], [
          build_group(body, { ..options, phantom: true, }),
        ])
        make_span(
          ["mord", "rlap"],
          [inner, make_span(["katex-fix"], [])],
          options~,
        )
      }
      Smash(body~, smash_height~, smash_depth~, ..) =>
        extra_smash(body, smash_height, smash_depth, options)
      VCenter(body~, ..) => {
        let body = build_group(body, options)
        let axis = options.metric("axisHeight")
        let shift = 0.5 * (body.height - axis - (body.depth + axis))
        make_vlist("shift", shift, [vlist_elem(body)], options)
      }
      RaiseBox(dy~, body~, ..) =>
        make_vlist(
          "shift",
          -calculate_size(dy, options),
          [vlist_elem(build_group(body, options))],
          options,
        )
      ReflectBox(body~, ..) =>
        make_span(
          ["mord", "reflectbox"],
          [build_group(body, options)],
          options~,
        )
      HBox(body~, ..) =>
        make_fragment(
          build_expression(body, { ..options, font: "", }, real_group=false),
        )
      Lap(alignment~, body~, ..) => extra_lap(alignment, body, options)
      Pmb(mclass~, body~, ..) => {
        let result = make_span(
          [extra_mclass(mclass)],
          build_expression(body, options),
          options~,
        )
        result.set_style("textShadow", "0.02em 0.01em 0.04px")
        result
      }
      Rule(width~, height~, shift~, ..) => {
        let result = make_span(["mord", "katex-rule"], [], options~)
        let width = calculate_size(width, options)
        let height = calculate_size(height, options)
        let shift = shift.map_or(0.0, value => calculate_size(value, options))
        result.set_style("borderRightWidth", make_em(width))
        result.set_style("borderTopWidth", make_em(height))
        result.set_style("bottom", make_em(shift))
        result.width = width
        result.height = height + shift
        result.depth = -shift
        result.max_font_size = height * 1.125 * options.size_multiplier
        result
      }
      IncludeGraphics(alt~, width~, height~, totalheight~, src~, ..) => {
        let height = calculate_size(height, options)
        let depth = if totalheight.number > 0.0 {
          calculate_size(totalheight, options) - height
        } else {
          0.0
        }
        let width = if width.number > 0.0 {
          calculate_size(width, options)
        } else {
          0.0
        }
        let result = html_node("img", classes=["mord"])
        result.set_attribute("src", src)
        result.set_attribute("alt", alt)
        result.set_style("height", make_em(height + depth))
        if width > 0.0 {
          result.set_style("width", make_em(width))
        }
        if depth > 0.0 {
          result.set_style("verticalAlign", make_em(-depth))
        }
        result.height = height
        result.depth = depth
        result
      }
      CdLabel(side~, label~, ..) => {
        let result = extra_wrap_fragment(
          build_group(
            label,
            options.with_style(style_sup(options.style)),
            base_options=options,
          ),
          options,
        )
        result.classes.push("cd-label-" + side)
        result.set_style("bottom", make_em(0.8 - result.depth))
        result.height = 0.0
        result.depth = 0.0
        result
      }
      CdParent(fragment~, ..) => {
        let result = extra_wrap_fragment(
          build_group(fragment, options),
          options,
        )
        result.classes.push("cd-vert-arrow")
        result
      }
      Cr(new_line~, size~, ..) => {
        let result = make_span(["mspace"], [], options~)
        if new_line {
          result.classes.push("katex-newline")
          if size is Some(value) {
            result.set_style(
              "marginTop",
              make_em(calculate_size(value, options)),
            )
          }
        }
        result
      }
      Verb(body~, star~, mode~, ..) => {
        let new_options = options.with_style(style_text(options.style))
        let symbols : Array[HtmlNode] = []
        for char in body {
          let text = match char {
            ' ' => if star { "␣" } else { "\u{00a0}" }
            '~' => "\\textasciitilde"
            _ => char.to_string()
          }
          symbols.push(
            make_symbol(text, "Typewriter-Regular", mode, new_options, classes=[
              "mord", "texttt",
            ]),
          )
        }
        try_combine_chars(symbols)
        make_span(
          ["mord", "text", ..new_options.sizing_classes(options)],
          symbols,
          options=new_options,
        )
      }
      Enclose(label~, body~, background_color~, border_color~, ..) =>
        extra_enclose(label, body, background_color, border_color, options)
      Array(
        body~,
        add_jot~,
        array_stretch~,
        columns~,
        row_gaps~,
        hskip_before_and_after~,
        hlines_before_row~,
        column_separation_type~,
        tags~,
        auto_tags~,
        ..
      ) =>
        extra_array(
          body, add_jot, array_stretch, columns, row_gaps, hskip_before_and_after,
          hlines_before_row, column_separation_type, tags, auto_tags, options,
        )
      _ => return None
    },
  )
}

///|
fn extra_wrap_fragment(node : HtmlNode, options : Options) -> HtmlNode {
  if node.kind == "fragment" {
    make_span([], [node], options~)
  } else {
    node
  }
}

///|
fn extra_mclass(family : @katex.AtomFamily) -> String {
  match family {
    Mord => "mord"
    Mop => "mop"
    Mbin => "mbin"
    Mrel => "mrel"
    Mopen => "mopen"
    Mclose => "mclose"
    Mpunct => "mpunct"
    Minner => "minner"
  }
}

///|
fn extra_smash(
  body : @katex.ParseNode,
  smash_height : Bool,
  smash_depth : Bool,
  options : Options,
) -> HtmlNode {
  let node = make_span([], [build_group(body, options)])
  guard smash_height || smash_depth else { return node }
  if smash_height {
    node.height = 0.0
  }
  if smash_depth {
    node.depth = 0.0
  }
  guard !(smash_height && smash_depth) else {
    return make_span(["mord", "katex-smash"], [node], options~)
  }
  for child in node.children {
    if smash_height {
      child.height = 0.0
    }
    if smash_depth {
      child.depth = 0.0
    }
  }
  make_span(
    ["mord"],
    [make_vlist("firstBaseline", 0.0, [vlist_elem(node)], options)],
    options~,
  )
}

///|
fn extra_lap(
  alignment : @katex.LapAlignment,
  body : @katex.ParseNode,
  options : Options,
) -> HtmlNode {
  let name = match alignment {
    LLap => "llap"
    RLap => "rlap"
    CLap => "clap"
  }
  let body = build_group(body, options)
  let inner = if alignment == CLap {
    make_span(["katex-inner"], [make_span([], [body])], options~)
  } else {
    make_span(["katex-inner"], [body])
  }
  let node = make_span([name], [inner, make_span(["katex-fix"], [])], options~)
  let strut = make_span(["katex-strut"], [])
  strut.set_style("height", make_em(node.height + node.depth))
  if node.depth != 0.0 {
    strut.set_style("verticalAlign", make_em(-node.depth))
  }
  node.children.insert(0, strut)
  make_span(
    ["mord", "katex-vbox"],
    [make_span(["katex-thinbox"], [node], options~)],
    options~,
  )
}
