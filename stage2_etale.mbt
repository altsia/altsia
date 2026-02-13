///|
pub type Stage2Etale

///|
pub(all) suberror Stage2EtaleError {
  TemplateArityMismatch(
    template_name~ : Name,
    expected~ : Int,
    got~ : Int,
    args~ : Array[Term],
    loc~ : SourceLoc?,
  )
  NestedTemplateDefinitionInSubstitution(term~ : Term, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
pub struct Template {
  params : Array[Name]
  body : Array[Term]
}

///|
pub type Env = @hashmap.HashMap[Name, Template]

///|
pub type ParamsEnv = @hashmap.HashMap[Name, Array[Term]]

///|
pub struct LocatedTemplate {
  params : Array[Name]
  body : Array[LocatedTerm]
}

///|
pub type LocatedEnv = @hashmap.HashMap[Name, LocatedTemplate]

///|
pub type LocatedParamsEnv = @hashmap.HashMap[Name, Array[LocatedTerm]]

///|
pub fn Stage2Etale::expand_program(terms : Array[Term]) -> Array[Term] raise {
  let env = @hashmap.HashMap::new()
  let program = []
  for term in terms {
    match term {
      TemplateDefinition(name, params, body) =>
        env[name] = Template::{ params, body }
      _ => program.push(term) // TemplateDefinition(...) ∉ program
    }
  }
  program.map(t => expand(env, t)).flatten()
}

///|
pub fn expand_args(env : Env, args : Array[Term]) -> Array[Term] raise {
  args.map(a => expand(env, a)).flatten()
}

///|
pub fn expand(env : Env, term : Term) -> Array[Term] raise {
  match term {
    App(name, args) if env.get(name) is Some(template) =>
      return expand_template_call(env, name, template, args)
    App(name, args) => [App(name, expand_args(env, args))]
    Splice(terms) => terms.map(t => expand(env, t)).flatten()
    Text(_) | Comment(_) => [term]
    TemplateDefinition(_) => panic() // unreachable, see: Stage2Etale::expand_program
  }
}

///|
pub fn expand_template_call(
  env : Env,
  template_name : Name,
  template : Template,
  args : Array[Term],
) -> Array[Term] raise {
  let args_length = args.length()
  let params_length = template.params.length()

  let mut args = args
  if params_length == 1 && args_length > 1 {
    args = [Splice(args)] // ad-hoc rule
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name=template_name,
      expected=params_length,
      got=args_length,
      args=args,
      loc=None,
    )
  }

  let expand_args = args.map(a => expand(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<template.params.length() {
    params_env[template.params[i]] = expand_args[i]
  }
  let substituted = template.body.map(t => substitute(params_env, t)).flatten()
  substituted.map(t => expand(env, t)).flatten()
}

///|
pub fn substitute(env : ParamsEnv, term : Term) -> Array[Term] raise {
  match term {
    Splice(terms) => [Splice(terms.map(t => substitute(env, t)).flatten())]
    App(name, []) if env.get(name) is Some(v) => v
    App(name, args) => [App(name, args.map(t => substitute(env, t)).flatten())]
    Text(_) | Comment(_) => [term]
    TemplateDefinition(_) =>
      raise Stage2EtaleError::NestedTemplateDefinitionInSubstitution(
        term=term,
        loc=None,
      )
  }
}

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
fn expand_spanned(env : LocatedEnv, term : LocatedTerm) -> Array[LocatedTerm] raise {
  match term {
    TApp(name, args, call_loc) if env.get(name) is Some(template) =>
      return expand_template_call_spanned(env, name, call_loc, template, args)
    TApp(name, args, loc) => [TApp(name, expand_args_spanned(env, args), loc)]
    TSplice(terms, _) => terms.map(t => expand_spanned(env, t)).flatten()
    TText(_, _) | TComment(_, _) => [term]
    TTemplateDefinition(_, _, _, _) => panic() // unreachable
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
      template_name=template_name,
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
