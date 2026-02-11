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
pub fn Stage2Etale::expand_program(terms : Array[Term]) -> Array[Term] {
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
pub fn expand_args(env : Env, args : Array[Term]) -> Array[Term] {
  args.map(a => expand(env, a)).flatten()
}

///|
pub fn expand(env : Env, term : Term) -> Array[Term] {
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
) -> Array[Term] {
  if args.length() != template.params.length() {
    try! fail("template arity mismatch: \{args}")
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
pub fn substitute(env : ParamsEnv, term : Term) -> Array[Term] {
  match term {
    Splice(terms) => [Splice(terms.map(t => substitute(env, t)).flatten())]
    App(name, []) if env.get(name) is Some(v) => v
    App(name, args) => [App(name, args.map(t => substitute(env, t)).flatten())]
    Text(_) | Comment(_) => [term]
    TemplateDefinition(_) =>
      try! fail("nested template def not allowed in substitute: \{term}") // unreachable
  }
}
