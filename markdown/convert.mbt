///|
fn escape_shape_text(value : String) -> String {
  value.replace_all(old="(", new="\\(").replace_all(old=")", new="\\)")
}

///|
fn render_shape_inline_quote(content : String) -> String {
  "`\{content}`"
}

///|
pub fn normalized_shape_to_source(node : NormalizedShape) -> String {
  match node {
    Text(value) => escape_shape_text(value)
    QuoteInline(content) => render_shape_inline_quote(content)
    App([Text("k"), QuoteInline(content)], _) => "k`\{content}`"
    App([Text("kd"), QuoteInline(content)], _) => "kd`\{content}`"
    App(args, gaps) => {
      let mut inline = ""
      for i in 0..<args.length() {
        let gap_before = if i == 0 { Tight } else { gaps[i - 1] }
        if i > 0 && gap_before == Space {
          inline = inline + " "
        }
        inline = inline + normalized_shape_to_source(args[i])
      }
      "(\{inline})"
    }
  }
}

///|
pub fn normalized_shapes_to_source(nodes : Array[NormalizedShape]) -> String {
  nodes.map(normalized_shape_to_source).join("\n\n")
}

///|
fn to_shapes_with_options(
  source : String,
  options : MarkdownConvertOptions,
) -> Array[NormalizedShape] {
  let document = MarkdownIt::parse_document(source)
  let ctx = build_convert_context(document, options.convert_katex)
  let shapes : Array[NormalizedShape] = []
  match metadata_to_shape(document.metadata, options.convert_katex) {
    Some(node) => shapes.push(node)
    None => ()
  }
  for node in make_lambda_declarations(document, ctx) {
    shapes.push(node)
  }
  for token in document.tokens {
    shapes.push(block_token_to_shape(token, ctx))
  }
  match make_footnotes_section_shape(ctx) {
    Some(node) => shapes.push(node)
    None => ()
  }
  shapes
}

///|
pub fn MarkdownIt::to_shapes(source : String) -> Array[NormalizedShape] {
  to_shapes_with_options(
    source,
    MarkdownConvertOptions::{ convert_katex: AlwaysApp },
  )
}

///|
pub fn MarkdownIt::to_altsia(
  source : String,
  normalize? : Bool = true,
  max_width? : Int = @core.default_max_width,
  options? : MarkdownConvertOptions = default_options,
) -> String raise {
  let rendered = to_shapes_with_options(source, options)
    |> normalized_shapes_to_source
  if normalize {
    @core.Stage1::normalize(rendered, max_width~)
  } else {
    rendered
  }
}
