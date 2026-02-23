///|
pub type Stage2Extern

///|
pub type AppRewriterRaise = (Name, Array[Term], SourceLoc) -> Array[Term] raise

///|
pub fn Stage2Extern::rewrite_apps(
  terms : Array[Term],
  rewriter : AppRewriter,
) -> Array[Term] {
  terms.map(t => rewrite_apps_in_term(t, rewriter)).flatten()
}

///|
pub fn Stage2Extern::rewrite_apps_raise(
  terms : Array[Term],
  rewriter : AppRewriterRaise,
) -> Array[Term] raise {
  terms.map(t => rewrite_apps_in_term_raise(t, rewriter)).flatten()
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
    TemplateDefinition(name, params, param_defaults, body, loc) =>
      [
        {
          let rewritten_defaults : Array[(Name, Array[Term])] = []
          for entry in param_defaults {
            rewritten_defaults.push(
              (
                entry.0,
                entry.1.map(t => rewrite_apps_in_term(t, rewriter)).flatten(),
              ),
            )
          }
          TemplateDefinition(
            name,
            params,
            rewritten_defaults,
            body.map(t => rewrite_apps_in_term(t, rewriter)).flatten(),
            loc,
          )
        },
      ]
    Text(_, _) | Comment(_, _) => [term]
  }
}

///|
fn rewrite_apps_in_term_raise(
  term : Term,
  rewriter : AppRewriterRaise,
) -> Array[Term] raise {
  match term {
    App(name, args, loc) => {
      let rewritten_args = args
        .map(t => rewrite_apps_in_term_raise(t, rewriter))
        .flatten()
      rewriter(name, rewritten_args, loc)
    }
    Splice(terms, loc) =>
      [
        Splice(
          terms.map(t => rewrite_apps_in_term_raise(t, rewriter)).flatten(),
          loc,
        ),
      ]
    TemplateDefinition(name, params, param_defaults, body, loc) =>
      [
        {
          let rewritten_defaults : Array[(Name, Array[Term])] = []
          for entry in param_defaults {
            rewritten_defaults.push(
              (
                entry.0,
                entry.1
                .map(t => rewrite_apps_in_term_raise(t, rewriter))
                .flatten(),
              ),
            )
          }
          TemplateDefinition(
            name,
            params,
            rewritten_defaults,
            body.map(t => rewrite_apps_in_term_raise(t, rewriter)).flatten(),
            loc,
          )
        },
      ]
    Text(_, _) | Comment(_, _) => [term]
  }
}
