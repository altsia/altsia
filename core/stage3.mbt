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
pub(all) suberror Stage3Error {
  AttributeExpectsAtMostOneValue(values~ : Array[Term], loc~ : SourceLoc?)
  UnexpectedTemplateDefinition(term~ : Term, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
fn lower_inline(node : Term) -> Array[InlineNode] raise {
  match node {
    Text(s, _) => [Text(s)]
    Splice(terms, _) => terms.map(lower_inline).flatten()
    App(name, args, _) => lower_span(name, args)
    Comment(_, _) => []
    TemplateDefinition(_, _, _, _, loc) =>
      raise Stage3Error::UnexpectedTemplateDefinition(term=node, loc=Some(loc))
  }
}

///|
fn lower_span(name : Name, args : Array[Term]) -> Array[InlineNode] raise {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Span({ name, attrs, children })]
}

///|
fn lower_block_app(name : Name, args : Array[Term]) -> Array[Piece] raise {
  match name {
    "p" => lower_paragraph(args)
    _ => lower_container_block(name, args)
  }
}

///|
fn lower_paragraph(args : Array[Term]) -> Array[Piece] raise {
  let inlines = args.map(lower_inline).flatten()
  [Block(Paragraph(inlines))]
}

///|
fn lower_container_block(name : Name, args : Array[Term]) -> Array[Piece] raise {
  let (attrs, body) = extract_attrs(args)
  let children = body.map(lower_inline).flatten()
  [Block(Container({ name, attrs, children }))]
}

///|
fn stage3_is_layout_gap_space(term : Term) -> Bool {
  match term {
    Text(" ", loc) => loc.start_offset == loc.end_offset
    _ => false
  }
}

///|
fn stage3_strip_layout_gap_spaces(values : Array[Term]) -> Array[Term] {
  let result = []
  for value in values {
    if !stage3_is_layout_gap_space(value) {
      result.push(value)
    }
  }
  result
}

///|
fn attr_value(term : Array[Term], loc : SourceLoc) -> String raise {
  let values = stage3_strip_layout_gap_spaces(term)
  match values {
    [] => ""
    [Text(s, _)] => s
    [t] => t.to_string()
    _ =>
      raise Stage3Error::AttributeExpectsAtMostOneValue(values~, loc=Some(loc))
  }
}

///|
fn extract_attrs(
  args : Array[Term],
) -> (@hashmap.HashMap[String, String], Array[Term]) raise {
  let entries = []
  let body = []
  for term in args {
    guard term is App(name, v, loc) && name.strip_prefix(":") is Some(key) else {
      body.push(term)
    }
    entries.push((key.to_string(), attr_value(v, loc)))
  }
  (@hashmap.HashMap::from_array(entries), body)
}

///|
fn lower_block(node : Term) -> Array[Piece] raise {
  match node {
    Comment(c, _) => [Comment(c)]
    Text(_, _) => [Block(Paragraph(lower_inline(node)))]
    Splice(terms, _) => terms.map(lower_block).flatten()
    App(name, args, _) => lower_block_app(name, args)
    TemplateDefinition(_, _, _, _, loc) =>
      raise Stage3Error::UnexpectedTemplateDefinition(term=node, loc=Some(loc))
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
