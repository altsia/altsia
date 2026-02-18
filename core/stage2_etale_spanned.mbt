///|
fn located_terms_to_plain_terms(terms : Array[LocatedTerm]) -> Array[Term] {
  terms.map(LocatedTerm::to_term)
}

///|
pub fn Stage2Etale::expand_program_spanned(
  terms : Array[LocatedTerm],
) -> Array[LocatedTerm] raise {
  let env = @hashmap.HashMap::new()
  let program = []
  for term in terms {
    match term {
      TTemplateDefinition(name, params, body, _) =>
        env[name] = LocatedTemplate::{ params, body }
      _ => program.push(term)
    }
  }
  program.map(t => expand_spanned(env, t)).flatten()
}

///|
fn expand_args_spanned(
  env : LocatedEnv,
  args : Array[LocatedTerm],
) -> Array[LocatedTerm] raise {
  args.map(a => expand_spanned(env, a)).flatten()
}

///|
fn expand_spanned(
  env : LocatedEnv,
  term : LocatedTerm,
) -> Array[LocatedTerm] raise {
  match term {
    TApp(name, args, call_loc) if env.get(name) is Some(template) =>
      return expand_template_call_spanned(env, name, call_loc, template, args)
    TApp(name, args, loc) => [TApp(name, expand_args_spanned(env, args), loc)]
    TSplice(terms, _) => terms.map(t => expand_spanned(env, t)).flatten()
    TText(_, _) | TComment(_, _) => [term]
    TTemplateDefinition(_, _, _, loc) =>
      raise Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(
        term=LocatedTerm::to_term(term),
        loc=Some(loc),
      )
  }
}

///|
fn expand_template_call_spanned(
  env : LocatedEnv,
  template_name : Name,
  call_loc : SourceLoc,
  template : LocatedTemplate,
  args : Array[LocatedTerm],
) -> Array[LocatedTerm] raise {
  let args_length = args.length()
  let params_length = template.params.length()

  let mut args = args
  if params_length == 1 && args_length > 1 {
    args = [TSplice(args, call_loc)] // ad-hoc rule
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected=params_length,
      got=args_length,
      args=located_terms_to_plain_terms(args),
      loc=Some(call_loc),
    )
  }

  let expand_args = args.map(a => expand_spanned(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<template.params.length() {
    params_env[template.params[i]] = expand_args[i]
  }
  let substituted = template.body
    .map(t => substitute_spanned(params_env, t))
    .flatten()
  substituted.map(t => expand_spanned(env, t)).flatten()
}

///|
fn substitute_spanned(
  env : LocatedParamsEnv,
  term : LocatedTerm,
) -> Array[LocatedTerm] raise {
  match term {
    TSplice(terms, loc) =>
      [TSplice(terms.map(t => substitute_spanned(env, t)).flatten(), loc)]
    TApp(name, [], _) if env.get(name) is Some(v) => v
    TApp(name, args, loc) =>
      [TApp(name, args.map(t => substitute_spanned(env, t)).flatten(), loc)]
    TText(_, _) | TComment(_, _) => [term]
    TTemplateDefinition(_, _, _, loc) =>
      raise Stage2EtaleError::NestedTemplateDefinitionInSubstitution(
        term=LocatedTerm::to_term(term),
        loc=Some(loc),
      )
  }
}
