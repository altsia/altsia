///|
pub type Stage2Etale

///|
pub(all) suberror Stage2EtaleError {
  TemplateArityMismatch(
    template_name~ : Name,
    expected~ : Int,
    got~ : Int,
    args~ : Array[LocatedTerm],
    loc~ : SourceLoc?
  )
  NestedTemplateDefinitionInSubstitution(term~ : LocatedTerm, loc~ : SourceLoc?)
  UnexpectedTemplateDefinitionInExpand(term~ : LocatedTerm, loc~ : SourceLoc?)
} derive(Eq, Show)

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
pub fn Stage2Etale::expand_program(
  terms : Array[LocatedTerm],
) -> Array[LocatedTerm] raise {
  let env = @hashmap.HashMap::new()
  let program = []
  for term in terms {
    match term {
      TemplateDefinition(name, params, body, _) =>
        env[name] = LocatedTemplate::{ params, body }
      _ => program.push(term)
    }
  }
  program.map(t => expand(env, t)).flatten()
}

///|
fn expand_args(
  env : LocatedEnv,
  args : Array[LocatedTerm],
) -> Array[LocatedTerm] raise {
  args.map(a => expand(env, a)).flatten()
}

///|
fn expand(
  env : LocatedEnv,
  term : LocatedTerm,
) -> Array[LocatedTerm] raise {
  match term {
    App(name, args, call_loc) if env.get(name) is Some(template) =>
      return expand_template_call(env, name, call_loc, template, args)
    App(name, args, loc) => [App(name, expand_args(env, args), loc)]
    Splice(terms, _) => terms.map(t => expand(env, t)).flatten()
    Text(_, _) | Comment(_, _) => [term]
    TemplateDefinition(_, _, _, loc) =>
      raise Stage2EtaleError::UnexpectedTemplateDefinitionInExpand(
        term~,
        loc=Some(loc),
      )
  }
}

///|
fn expand_template_call(
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
    args = [Splice(args, call_loc)] // ad-hoc rule
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected=params_length,
      got=args_length,
      args~,
      loc=Some(call_loc),
    )
  }

  let expand_args = args.map(a => expand(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<template.params.length() {
    params_env[template.params[i]] = expand_args[i]
  }
  let substituted = template.body
    .map(t => substitute(params_env, t))
    .flatten()
  substituted.map(t => expand(env, t)).flatten()
}

///|
fn substitute(
  env : LocatedParamsEnv,
  term : LocatedTerm,
) -> Array[LocatedTerm] raise {
  match term {
    Splice(terms, loc) =>
      [Splice(terms.map(t => substitute(env, t)).flatten(), loc)]
    App(name, [], _) if env.get(name) is Some(v) => v
    App(name, args, loc) =>
      [App(name, args.map(t => substitute(env, t)).flatten(), loc)]
    Text(_, _) | Comment(_, _) => [term]
    TemplateDefinition(_, _, _, loc) =>
      raise Stage2EtaleError::NestedTemplateDefinitionInSubstitution(
        term~,
        loc=Some(loc),
      )
  }
}
