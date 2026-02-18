///|
pub type Stage2Extern

///|
pub fn Stage2Extern::rewrite_apps(
  terms : Array[Term],
  rewriter : AppRewriter,
) -> Array[Term] {
  terms.map(t => rewrite_apps_in_term(t, rewriter)).flatten()
}

///|
fn rewrite_apps_in_term(term : Term, rewriter : AppRewriter) -> Array[Term] {
  match term {
    App(name, args, loc) => {
      let rewritten_args = args
        .map(t => rewrite_apps_in_term(t, rewriter))
        .flatten()
      rewriter(name, rewritten_args, loc)
    }
    Splice(terms, loc) =>
      [Splice(terms.map(t => rewrite_apps_in_term(t, rewriter)).flatten(), loc)]
    TemplateDefinition(name, params, body, loc) =>
      [
        TemplateDefinition(
          name,
          params,
          body.map(t => rewrite_apps_in_term(t, rewriter)).flatten(),
          loc,
        ),
      ]
    Text(_, _) | Comment(_, _) => [term]
  }
}
