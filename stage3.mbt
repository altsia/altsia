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
} derive(Eq, Show)

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
    _ => raise Stage3Error::AttributeExpectsAtMostOneValue(values=term, loc=None)
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

///|
fn located_terms_to_terms(terms : Array[LocatedTerm]) -> Array[Term] {
  terms.map(LocatedTerm::to_term)
}

///|
fn lower_inline_spanned(node : LocatedTerm) -> Array[InlineNode] raise {
  match node {
    TText(s, _) => [Text(s)]
    TSplice(terms, _) => terms.map(lower_inline_spanned).flatten()
    TApp(name, args, _) => lower_span_spanned(name, args)
    TComment(_, _) => []
    TTemplateDefinition(_, _, _, _) => panic() // unreachable
  }
}

///|
fn lower_span_spanned(name : Name, args : Array[LocatedTerm]) -> Array[InlineNode] raise {
  let (attrs, body) = extract_attrs_spanned(args)
  let children = body.map(lower_inline_spanned).flatten()
  [Span({ name, attrs, children })]
}

///|
fn lower_block_app_spanned(
  name : Name,
  args : Array[LocatedTerm],
) -> Array[Piece] raise {
  match name {
    "p" => lower_paragraph_spanned(args)
    _ => lower_container_block_spanned(name, args)
  }
}

///|
fn lower_paragraph_spanned(args : Array[LocatedTerm]) -> Array[Piece] raise {
  let inlines = args.map(lower_inline_spanned).flatten()
  [Block(Paragraph(inlines))]
}

///|
fn lower_container_block_spanned(
  name : Name,
  args : Array[LocatedTerm],
) -> Array[Piece] raise {
  let (attrs, body) = extract_attrs_spanned(args)
  let children = body.map(lower_inline_spanned).flatten()
  [Block(Container({ name, attrs, children }))]
}

///|
fn attr_value_spanned(term : Array[LocatedTerm], loc : SourceLoc) -> String raise {
  match term {
    [] => ""
    [TText(s, _)] => s
    [t] => LocatedTerm::to_term(t).to_string()
    _ =>
      raise Stage3Error::AttributeExpectsAtMostOneValue(
        values=located_terms_to_terms(term),
        loc=Some(loc),
      )
  }
}

///|
fn extract_attrs_spanned(
  args : Array[LocatedTerm],
) -> (@hashmap.HashMap[String, String], Array[LocatedTerm]) raise {
  let entries = []
  let body = []
  for term in args {
    guard term is TApp(name, v, loc) && name.strip_prefix(":") is Some(key) else {
      body.push(term)
    }
    entries.push((key.to_string(), attr_value_spanned(v, loc)))
  }
  (@hashmap.HashMap::from_array(entries), body)
}

///|
fn lower_block_spanned(node : LocatedTerm) -> Array[Piece] raise {
  match node {
    TComment(c, _) => [Comment(c)]
    TText(_, _) => [Block(Paragraph(lower_inline_spanned(node)))]
    TSplice(terms, _) => terms.map(lower_block_spanned).flatten()
    TApp(name, args, _) => lower_block_app_spanned(name, args)
    TTemplateDefinition(_, _, _, _) => panic() // unreachable
  }
}

///|
pub fn Stage3::pass_spanned(nodes : Array[LocatedTerm]) -> Doc raise {
  let phase = []
  for node in nodes {
    phase.append(lower_block_spanned(node))
  }
  phase
}
