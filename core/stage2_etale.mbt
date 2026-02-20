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
  MissingNamedArgument(
    template_name~ : Name,
    param_name~ : Name,
    loc~ : SourceLoc?
  )
  DuplicateNamedArgument(
    template_name~ : Name,
    param_name~ : Name,
    loc~ : SourceLoc?
  )
  NestedTemplateDefinitionInSubstitution(term~ : Term, loc~ : SourceLoc?)
  UnexpectedTemplateDefinitionInExpand(term~ : Term, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
pub struct Template {
  params : Array[Name]
  param_defaults : Array[(Name, Array[Term])]
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
      TemplateDefinition(name, params, param_defaults, body, _) =>
        env[name] = Template::{ params, param_defaults, body }
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
fn stage2_etale_is_named_param(name : Name) -> Bool {
  name.strip_prefix(":") is Some(_)
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
fn stage2_etale_find_default(
  defaults : Array[(Name, Array[Term])],
  param_name : Name,
) -> Array[Term]? {
  for entry in defaults {
    let name = entry.0
    if name == param_name {
      return Some(entry.1)
    }
  }
  None
}

///|
fn stage2_etale_has_named_param(params : Array[Name], candidate : Name) -> Bool {
  for param in params {
    if stage2_etale_is_named_param(param) && param == candidate {
      return true
    }
  }
  false
}

///|
fn stage2_etale_named_arg_value(
  values : Array[Term],
  loc : SourceLoc,
) -> Array[Term] {
  let semantic_values = stage2_etale_strip_layout_gap_spaces(values)
  if semantic_values.is_empty() {
    [Text("", loc)]
  } else {
    values
  }
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
    TemplateDefinition(_, _, _, _, loc) =>
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
  let positional_params : Array[Name] = []
  let named_params : Array[Name] = []
  for param in template.params {
    if stage2_etale_is_named_param(param) {
      named_params.push(param)
    } else {
      positional_params.push(param)
    }
  }
  let positional_args : Array[Term] = []
  let named_values : ParamsEnv = @hashmap.HashMap::new()
  for arg in semantic_args {
    match arg {
      App(name, values, loc) if stage2_etale_is_named_param(name) &&
        stage2_etale_has_named_param(named_params, name) => {
        if named_values.get(name) is Some(_) {
          raise Stage2EtaleError::DuplicateNamedArgument(
            template_name~,
            param_name=name,
            loc=Some(loc),
          )
        }
        named_values[name] = stage2_etale_named_arg_value(values, loc)
      }
      _ => positional_args.push(arg)
    }
  }

  let args_length = positional_args.length()
  let params_length = positional_params.length()
  let has_variadic_tail = params_length > 0 &&
    stage2_etale_has_variadic_suffix(positional_params[params_length - 1])
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
        args=positional_args,
        loc=Some(call_loc),
      )
    }
    let result = []
    for i in 0..<fixed_count {
      result.push(positional_args[i])
    }
    result.push(
      stage2_etale_box_as_splice(positional_args[fixed_count:], call_loc),
    )
    result
  } else if params_length != args_length {
    raise Stage2EtaleError::TemplateArityMismatch(
      template_name~,
      expected=params_length,
      got=args_length,
      args=positional_args,
      loc=Some(call_loc),
    )
  } else {
    positional_args
  }

  let expanded_positional_args = call_args.map(a => expand(env, a))
  let params_env = @hashmap.HashMap::new()
  for i in 0..<positional_params.length() {
    let param_name = positional_params[i]
    stage2_etale_bind_param(
      params_env,
      param_name,
      expanded_positional_args[i],
      has_variadic_tail && i == params_length - 1,
    )
  }
  for param_name in named_params {
    let raw_value = match named_values.get(param_name) {
      Some(value) => value
      None =>
        match stage2_etale_find_default(template.param_defaults, param_name) {
          Some(value) => value
          None =>
            raise Stage2EtaleError::MissingNamedArgument(
              template_name~,
              param_name~,
              loc=Some(call_loc),
            )
        }
    }
    stage2_etale_bind_param(
      params_env,
      param_name,
      raw_value.map(a => expand(env, a)).flatten(),
      false,
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
    TemplateDefinition(_, _, _, _, loc) =>
      raise Stage2EtaleError::NestedTemplateDefinitionInSubstitution(
        term~,
        loc=Some(loc),
      )
  }
}
