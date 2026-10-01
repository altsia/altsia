///|
/// Named CSS/xcolor colors to hex, since Typst's `rgb` only accepts hex
/// strings. KaTeX passes names through to CSS; this table restores the
/// resolution for the common cases. Unknown names fall back to the name
/// itself, which Typst's predefined color variables may still accept.
let named_colors : Map[String, String] = Map::from_array([
  ("black", "#000000"),
  ("gray", "#808080"),
  ("grey", "#808080"),
  ("white", "#ffffff"),
  ("red", "#ff0000"),
  ("green", "#008000"),
  ("blue", "#0000ff"),
  ("cyan", "#00ffff"),
  ("magenta", "#ff00ff"),
  ("yellow", "#ffff00"),
  ("orange", "#ffa500"),
  ("purple", "#800080"),
  ("brown", "#a52a2a"),
  ("pink", "#ffc0cb"),
  ("lime", "#00ff00"),
  ("teal", "#008080"),
  ("navy", "#000080"),
  ("olive", "#808000"),
  ("maroon", "#800000"),
  ("silver", "#c0c0c0"),
  ("aqua", "#00ffff"),
  ("fuchsia", "#ff00ff"),
  ("gold", "#ffd700"),
  ("indigo", "#4b0082"),
  ("khaki", "#f0e68c"),
  ("lavender", "#e6e6fa"),
  ("coral", "#ff7f50"),
  ("crimson", "#dc143c"),
  ("salmon", "#fa8072"),
  ("tan", "#d2b48c"),
  ("turquoise", "#40e0d0"),
  ("violet", "#ee82ee"),
  ("beige", "#f5f5dc"),
  ("ivory", "#fffff0"),
  ("mint", "#98ff98"),
  ("rose", "#ff007f"),
  ("skyblue", "#87ceeb"),
  ("violetred", "#d02090"),
  ("springgreen", "#00ff7f"),
  ("seagreen", "#2e8b57"),
  ("royalblue", "#4169e1"),
  ("rebeccapurple", "#663399"),
  ("orangered", "#ff4500"),
  ("oldlace", "#fdf5e6"),
  ("mistyrose", "#ffe4e1"),
  ("midnightblue", "#191970"),
  ("mediumpurple", "#9370db"),
  ("mediumorchid", "#ba55d3"),
  ("mediumblue", "#0000cd"),
  ("limegreen", "#32cd32"),
  ("lightcoral", "#f08080"),
  ("indianred", "#cd5c5c"),
  ("hotpink", "#ff69b4"),
  ("greenyellow", "#adff2f"),
  ("forestgreen", "#228b22"),
  ("dodgerblue", "#1e90ff"),
  ("darkviolet", "#9400d3"),
  ("darkturquoise", "#00ced1"),
  ("darkslateblue", "#483d8b"),
  ("darksalmon", "#e9967a"),
  ("darkred", "#8b0000"),
  ("darkorange", "#ff8c00"),
  ("darkmagenta", "#8b008b"),
  ("darkgreen", "#006400"),
  ("darkgray", "#a9a9a9"),
  ("darkblue", "#00008b"),
  ("cyanblue", "#0ff"),
  ("chocolate", "#d2691e"),
  ("cadetblue", "#5f9ea0"),
  ("burlywood", "#deb887"),
  ("blueviolet", "#8a2be2"),
  ("bisque", "#ffe4c4"),
  ("aquamarine", "#7fffd4"),
  ("aliceblue", "#f0f8ff"),
  ("darkorchid", "#9932cc"),
  ("darkslategray", "#2f4f4f"),
  ("darkgoldenrod", "#b8860b"),
  ("deeppink", "#ff1493"),
  ("deepskyblue", "#00bfff"),
  ("dimgray", "#696969"),
  ("firebrick", "#b22222"),
  ("gainsboro", "#dcdcdc"),
  ("honeydew", "#f0fff0"),
  ("lightblue", "#add8e6"),
  ("lightgoldenrodyellow", "#fafad2"),
  ("lightgray", "#d3d3d3"),
  ("lightgreen", "#90ee90"),
  ("lightpink", "#ffb6c1"),
  ("lightsalmon", "#ffa07a"),
  ("lightseagreen", "#20b2aa"),
  ("lightskyblue", "#87cefa"),
  ("lightslateblue", "#8470ff"),
  ("lightsteelblue", "#b0c4de"),
  ("lightyellow", "#ffffe0"),
  ("limegreen", "#32cd32"),
  ("mediumaquamarine", "#66cdaa"),
  ("mediumseagreen", "#3cb371"),
  ("mediumslateblue", "#7b68ee"),
  ("mediumspringgreen", "#00fa9a"),
  ("mediumturquoise", "#48d1cc"),
  ("mediumvioletred", "#c71585"),
  ("navajowhite", "#ffdead"),
  ("orchid", "#da70d6"),
  ("palegoldenrod", "#eee8aa"),
  ("palegreen", "#98fb98"),
  ("paleturquoise", "#afeeee"),
  ("palevioletred", "#db7093"),
  ("peachpuff", "#ffdab9"),
  ("peru", "#cd853f"),
  ("plum", "#dda0dd"),
  ("powderblue", "#b0e0e6"),
  ("rosybrown", "#bc8f8f"),
  ("saddlebrown", "#8b4513"),
  ("sandybrown", "#f4a460"),
  ("seashell", "#fff5ee"),
  ("sienna", "#a0522d"),
  ("skyblue", "#87ceeb"),
  ("slateblue", "#6a5acd"),
  ("slategray", "#708090"),
  ("snow", "#fffafa"),
  ("steelblue", "#4682b4"),
  ("thistle", "#d8bfd8"),
  ("tomato", "#ff6347"),
  ("wheat", "#f5deb3"),
  ("whitesmoke", "#f5f5f5"),
  ("yellowgreen", "#9acd32"),
])

///|
fn render_color(
  color : String,
  body : Array[@katex.ParseNode],
  state : RenderState,
) -> String {
  let fill = color_fill(color)
  "text(fill: #\{fill}, \{render_nodes(body, state)})"
}

///|
fn color_fill(color : String) -> String {
  if color.has_prefix("#") {
    "rgb(\"\{color}\")"
  } else {
    named_colors.get(color).map_or(color, hex => "rgb(\"\{hex}\")")
  }
}

///|
fn render_enclose(
  label : String,
  body : @katex.ParseNode,
  background_color : String?,
  border_color : String?,
  state : RenderState,
) -> String {
  let content = render_node(body, state)
  match (label, background_color, border_color) {
    ("\\colorbox", Some(bg), _) => "#box(fill: \{color_fill(bg)}, $\{content}$)"
    ("\\fcolorbox", Some(bg), Some(border)) =>
      "#box(stroke: 0.5pt + \{color_fill(border)}, fill: \{color_fill(bg)}, $\{content}$)"
    (_, _, _) => "#box(stroke: 0.5pt, $\{content}$)"
  }
}
