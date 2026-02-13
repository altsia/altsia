///|
pub type Stage2Etale

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
pub fn Stage2Etale::expand_program(terms : Array[Term]) -> Array[Term] raise {
  let env = @hashmap.HashMap::new()
  let program = []
  for term in terms {
    match term {
      TemplateDefinition(name, params, body) => env[name] = { params, body }
      _ => program.push(term)
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
      return expand_template_call(env, template, args)
    App(name, args) => [App(name, expand_args(env, args))]
    Splice(terms) => terms.map(t => expand(env, t)).flatten()
    Text(_) | Comment(_) => [term]
    TemplateDefinition(_) => panic() // unreachable
  }
}

///|
pub fn expand_template_call(
  env : Env,
  template : Template,
  args : Array[Term],
) -> Array[Term] raise {
  let args_length = args.length()
  let params_length = template.params.length()

  let mut args = args
  if params_length == 1 && args_length > 1 {
    args = [Splice(args)] // ad-hoc rule
  } else if params_length != args_length {
    fail("template arity mismatch: expected \{params_length}, got \{args_length}: \{args}")
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
      fail("nested template definition is not allowed in substitution: \{term}") // unreachable
  }
}
