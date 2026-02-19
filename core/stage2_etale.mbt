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
fn stage2_etale_has_variadic_suffix(name : Name) -> Bool {
  let len = name.length()
  len >= 3 && name.unsafe_substring(start=len - 3, end=len) == "..."
}

///|
fn stage2_etale_strip_variadic_suffix(name : Name) -> Name {
  if stage2_etale_has_variadic_suffix(name) {
    name.unsafe_substring(start=0, end=name.length() - 3)
  } else {
    name
  }
}

///|
fn stage2_etale_gap_separator_loc(next : Term) -> SourceLoc {
  let loc = next.loc()
  {
    start_offset: loc.start_offset,
    end_offset: loc.start_offset,
    line: loc.line,
    column: loc.column,
  }
}

///|
fn stage2_etale_box_as_splice(
  args : ArrayView[Term],
  call_loc : SourceLoc,
) -> Term {
  let boxed = []
  for i in 0..<args.length() {
    if i > 0 {
      boxed.push(Term::Text(" ", stage2_etale_gap_separator_loc(args[i])))
    }
    boxed.push(args[i])
  }
  Splice(boxed, call_loc)
}

///|
fn stage2_etale_bind_param(
  params_env : ParamsEnv,
  param_name : Name,
  value : Array[Term],
  variadic_tail : Bool,
) -> Unit {
  if variadic_tail {
    let normalized = stage2_etale_strip_variadic_suffix(param_name)
    params_env[normalized] = value
    if normalized != param_name {
      // Keep backward compatibility if body still references the raw `name...`.
      params_env[param_name] = value
    }
  } else {
    params_env[param_name] = value
  }
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
  let has_variadic_tail = params_length > 0 &&
    stage2_etale_has_variadic_suffix(template.params[params_length - 1])
  let fixed_count = if has_variadic_tail {
    params_length - 1
  } else {
    params_length
  }

  let call_args = if has_variadic_tail {
    if args_length < params_length {
      raise Stage2EtaleError::TemplateArityMismatch(
        template_name~,
        expected=params_length,
        got=args_length,
        args=semantic_args,
        loc=Some(call_loc),
      )
    }
    let result = []
    for i in 0..<fixed_count {
      result.push(semantic_args[i])
    }
    result.push(
      stage2_etale_box_as_splice(semantic_args[fixed_count:], call_loc),
    )
    result
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected=params_length,
      got=args_length,
      args=semantic_args,
      loc=Some(call_loc),
    )
  } else {
    semantic_args
  }

  let expand_args = call_args.map(a => expand(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<template.params.length() {
    let param_name = template.params[i]
    stage2_etale_bind_param(
      params_env,
      param_name,
      expand_args[i],
      has_variadic_tail && i == params_length - 1,
    )
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
