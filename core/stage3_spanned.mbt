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
    TTemplateDefinition(_, _, _, loc) =>
      raise Stage3Error::UnexpectedTemplateDefinition(
        term=LocatedTerm::to_term(node),
        loc=Some(loc),
      )
  }
}

///|
fn lower_span_spanned(
  name : Name,
  args : Array[LocatedTerm],
) -> Array[InlineNode] raise {
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
fn attr_value_spanned(
  term : Array[LocatedTerm],
  loc : SourceLoc,
) -> String raise {
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
    TTemplateDefinition(_, _, _, loc) =>
      raise Stage3Error::UnexpectedTemplateDefinition(
        term=LocatedTerm::to_term(node),
        loc=Some(loc),
      )
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
