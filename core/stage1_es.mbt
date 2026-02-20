///|
pub(all) enum ES {
  EText(String)
  EQuote(String)
  EQuoteInline(String)
  EApp(Array[ES])
} derive(Eq, Show)

///|
pub fn S::to_es(node : S) -> ES {
  match node {
    Text(s, _) => EText(s)
    QuoteBlock(s, _) => EQuote(s)
    QuoteInline(s, _) => EQuoteInline(s)
    App(args, _, _) => EApp(args.map(S::to_es))
  }
}

///|
pub fn Stage1::parse_semantics(source : String) -> Array[ES] raise {
  Stage1::parse(source).map(S::to_es)
}
