///|
pub type Doc = Array[Piece]

///|
pub(all) enum Piece {
  Inline(InlineNode)
  Block(BlockNode)
  Comment(String)
} derive(Eq, Show, Debug)

///|
pub(all) enum InlineNode {
  Text(String)
  Span(Element[InlineNode])
} derive(Eq, Show, Debug)

///|
pub(all) enum BlockNode {
  Paragraph(Array[InlineNode])
  Container(Element[InlineNode])
} derive(Eq, Show, Debug)

///|
pub type Stage3

///|
pub fn lower_inline(node : Term) -> Array[InlineNode] raise {
  match node {
    Text(s) => [Text(s)]
    Splice(terms) => terms.map(lower_inline).flatten()
    App(name, args) => lower_span(name, args)
    Comment(_) => []
    TemplateDefinition(_) => panic() // unreachable
  }
}

///|
pub fn lower_span(name : Name, args : Array[Term]) -> Array[InlineNode] raise {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Span({ name, attrs, children })]
}

///|
pub fn lower_block_app(name : Name, args : Array[Term]) -> Array[Piece] raise {
  match name {
    "p" => lower_paragraph(args)
    _ => lower_container_block(name, args)
  }
}

///|
pub fn lower_paragraph(args : Array[Term]) -> Array[Piece] raise {
  let inlines = args.map(lower_inline).flatten()
  [Block(Paragraph(inlines))]
}

///|
pub fn lower_container_block(name : Name, args : Array[Term]) -> Array[Piece] raise {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Block(Container({ name, attrs, children }))]
}

///|
pub fn attr_value(term : Array[Term]) -> String raise {
  match term {
    [] => ""
    [Text(s)] => s
    [t] => t.to_string()
    _ => fail("attribute expects at most one value: \{term}")
  }
}

///|
pub fn extract_attrs(
  args : Array[Term],
) -> (@hashmap.HashMap[String, String], Array[Term]) raise {
  let entries = []
  let body = []
  for term in args {
    guard term is App(name, v) && name.strip_prefix(":") is Some(key) else {
      body.push(term)
    }
    entries.push((key.to_string(), attr_value(v)))
  }
  (@hashmap.HashMap::from_array(entries), body)
}

///|
pub fn lower_block(node : Term) -> Array[Piece] raise {
  match node {
    Comment(c) => [Comment(c)]
    Text(_) => [Block(Paragraph(lower_inline(node)))]
    Splice(terms) => terms.map(lower_block).flatten()
    App(name, args) => lower_block_app(name, args)
    TemplateDefinition(_) => panic() // unreachable
  }
}

///|
pub fn Stage3::pass(nodes : Array[Term]) -> Doc raise {
  let phase = []
  for node in nodes {
    phase.append(lower_block(node))
  }
  phase
}
