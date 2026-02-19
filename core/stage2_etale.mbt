///|
pub type Stage2Etale

///|
pub(all) suberror Stage2EtaleError {
  TemplateArityMismatch(
    template_name~ : Name,
    expected~ : Int,
    got~ : Int,
    args~ : Array[Term],
    loc~ : SourceLoc?
  )
  NestedTemplateDefinitionInSubstitution(term~ : Term, loc~ : SourceLoc?)
  UnexpectedTemplateDefinitionInExpand(term~ : Term, loc~ : SourceLoc?)
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
pub type AppRewriter = (Name, Array[Term], SourceLoc) -> Array[Term]

///|
pub fn Stage2Etale::expand_program(terms : Array[Term]) -> Array[Term] raise {
  let env = @hashmap.HashMap::new()
  let program = []
  for term in terms {
    match term {
      TemplateDefinition(name, params, body, _) =>
        env[name] = Template::{ params, body }
      _ => program.push(term)
    }
  }
  program.map(t => expand(env, t)).flatten()
}

///|
fn stage2_etale_is_layout_gap_space(term : Term) -> Bool {
  match term {
    Text(" ", loc) => loc.start_offset == loc.end_offset
    _ => false
  }
}

///|
fn stage2_etale_strip_layout_gap_spaces(args : Array[Term]) -> Array[Term] {
  let result = []
  for arg in args {
    if !stage2_etale_is_layout_gap_space(arg) {
      result.push(arg)
    }
  }
  result
}

///|
fn expand_args(env : Env, args : Array[Term]) -> Array[Term] raise {
  args.map(a => expand(env, a)).flatten()
}

///|
fn expand(env : Env, term : Term) -> Array[Term] raise {
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
  env : Env,
  template_name : Name,
  call_loc : SourceLoc,
  template : Template,
  args : Array[Term],
) -> Array[Term] raise {
  let semantic_args = stage2_etale_strip_layout_gap_spaces(args)
  let args_length = semantic_args.length()
  let params_length = template.params.length()

  let mut call_args = semantic_args
  if params_length == 1 && args_length > 1 {
    call_args = [Splice(call_args, call_loc)] // ad-hoc rule
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected=params_length,
      got=args_length,
      args=semantic_args,
      loc=Some(call_loc),
    )
  }

  let expand_args = call_args.map(a => expand(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<template.params.length() {
    params_env[template.params[i]] = expand_args[i]
  }
  let substituted = template.body.map(t => substitute(params_env, t)).flatten()
  substituted.map(t => expand(env, t)).flatten()
}

///|
fn substitute(env : ParamsEnv, term : Term) -> Array[Term] raise {
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
