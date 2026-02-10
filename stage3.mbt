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
  InlineMath(String)
  Value(String)
  Span(AttributedNode)
} derive(Eq, Show, Debug)

///|
pub(all) enum BlockNode {
  MathBlock(String)
  Paragraph(Array[InlineNode])
  CodeBlock(AttributedNode)
  Container(AttributedNode)
} derive(Eq, Show, Debug)

///|
pub(all) struct AttributedNode {
  name : Name
  attrs : @hashmap.HashMap[String, String]
  children : Array[InlineNode]
} derive(Eq, Show, Debug)

///|
pub type Stage3

///|
pub fn lower_inline(node : Term) -> Array[InlineNode] {
  match node {
    Text(s) => [Text(s)]
    Splice(terms) => terms.map(lower_inline).flatten()
    App(name, args) => lower_inline_app(name, args)
    Comment(_) => []
  }
}

///|
pub fn lower_inline_app(name : Name, args : Array[Term]) -> Array[InlineNode] {
  match name {
    "$" => lower_inline_math(args)
    _ => lower_span(name, args)
  }
}

///|
pub fn lower_inline_math(args : Array[Term]) -> Array[InlineNode] {
  match args {
    [Text(s)] => [InlineMath(s)]
    _ => try! fail("inline math expects text: \{args}")
  }
}

///|
pub fn lower_span(name : Name, args : Array[Term]) -> Array[InlineNode] {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Span({ name, attrs, children })]
}

///|
pub fn lower_block_app(name : Name, args : Array[Term]) -> Array[Piece] {
  match name {
    "p" => lower_paragraph(args)
    "math" => lower_math_block(args)
    "code" => lower_code_block(args)
    _ => lower_container_block(name, args)
  }
}

///|
pub fn lower_paragraph(args : Array[Term]) -> Array[Piece] {
  let inlines = args.map(lower_inline).flatten()
  [Block(Paragraph(inlines))]
}

///|
pub fn lower_math_block(args : Array[Term]) -> Array[Piece] {
  match args {
    [Text(raw)] => [Block(MathBlock(raw))]
    _ => try! fail("math block expects exactly one raw block: \{args}")
  }
}

///|
pub fn lower_code_block(args : Array[Term]) -> Array[Piece] {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Block(CodeBlock({ name: "code", attrs, children }))]
}

///|
pub fn lower_container_block(name : Name, args : Array[Term]) -> Array[Piece] {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Block(Container({ name, attrs, children }))]
}

///|
pub fn attr_value(term : Array[Term]) -> String {
  match term {
    [] => "true"
    [Text(s)] => s
    [t] => t.to_string()
    _ => try! fail("attribute expects at most one value: \{term}")
  }
}

///|
pub fn extract_attrs(
  args : Array[Term],
) -> (@hashmap.HashMap[String, String], Array[Term]) {
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
pub fn lower_block(node : Term) -> Array[Piece] {
  match node {
    Comment(c) => [Comment(c)]
    Text(_) => [Block(Paragraph(lower_inline(node)))]
    Splice(terms) => terms.map(lower_block).flatten()
    App(name, args) => lower_block_app(name, args)
  }
}

///|
pub fn Stage3::pass(nodes : Array[Term]) -> Doc {
  let phase = []
  for node in nodes {
    phase.append(lower_block(node))
  }
  phase
}
