///|
pub(all) struct CompileEnv {
  bindings : Array[Binding]
}

///|
pub(all) struct Binding {
  name : String
  value : BindingValue
}

///|
pub(all) enum BindingValue {
  BoundValue(Value)
  BoundTemplate(Template)
}

///|
pub(all) struct Template {
  params : Array[String]
  body : Array[Node]
  env : CompileEnv
}

///|
priv struct TemplateCall {
  attrs : Array[Attr]
  children : Array[Node]
  span : SourceSpan
}

///|
priv struct TemplateArguments {
  values : Array[Value?]
}

///|
pub(all) struct BindingCollectOptions {
  include_doc : Bool
  include_let : Bool
  include_def : Bool
}

///|
pub fn BindingCollectOptions::default() -> BindingCollectOptions {
  { include_doc: true, include_let: true, include_def: true }
}

///|
pub fn CompileEnv::empty() -> CompileEnv {
  { bindings: [] }
}

///|
pub fn CompileEnv::copy(self : CompileEnv) -> CompileEnv {
  { bindings: self.bindings.copy() }
}

///|
pub fn CompileEnv::append(self : CompileEnv, other : CompileEnv) -> Unit {
  self.bindings.append(other.bindings)
}

///|
fn Binding::value_named(self : Binding, name : String) -> Value? {
  if self.name == name && self.value is BoundValue(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn Binding::template_named(self : Binding, name : String) -> Template? {
  if self.name == name && self.value is BoundTemplate(template) {
    Some(template)
  } else {
    None
  }
}

///|
// Scans in reverse so the most recently bound name wins (shadowing).
pub fn CompileEnv::lookup_value(self : CompileEnv, name : String) -> Value? {
  let bindings = self.bindings
  let mut index = bindings.length()
  while index > 0 {
    index -= 1
    if bindings[index].value_named(name) is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn CompileEnv::bind_value(
  self : CompileEnv,
  name : String,
  value : Value,
) -> Unit {
  self.bindings.push({ name, value: BindingValue::BoundValue(value) })
}

///|
// Scans in reverse so the most recently bound name wins (shadowing).
pub fn CompileEnv::lookup_template(
  self : CompileEnv,
  name : String,
) -> Template? {
  let bindings = self.bindings
  let mut index = bindings.length()
  while index > 0 {
    index -= 1
    if bindings[index].template_named(name) is Some(template) {
      return Some(template)
    }
  }
  None
}

///|
pub fn CompileEnv::bind_template(
  self : CompileEnv,
  name : String,
  params : Array[String],
  body : Array[Node],
) -> Unit {
  self.bindings.push({
    name,
    value: BindingValue::BoundTemplate({ params, body, env: self.copy() }),
  })
}

///|
pub fn CompileEnv::bind_doc_attr(self : CompileEnv, attr : Attr) -> Unit {
  if attr.value is Some(value) {
    self.bind_value(attr.name, value)
  }
}

///|
pub fn collect_bindings(
  doc : Document,
  base? : CompileEnv,
  options? : BindingCollectOptions,
) -> Result[CompileEnv, Diagnostic] {
  let env = base.map(b => b.copy()).unwrap_or(CompileEnv::empty())
  let opts = options.unwrap_or(BindingCollectOptions::default())
  if opts.include_def {
    prebind_templates(env, doc.nodes)
  }
  for node in doc.nodes {
    match node {
      Let(name, value, _) if opts.include_let => env.bind_value(name, value)
      Def(name, params, body, _) if opts.include_def =>
        env.bind_template(name, params, body)
      Doc(attrs, _) if opts.include_doc =>
        for attr in attrs {
          env.bind_doc_attr(attr)
        }
      _ => ()
    }
  }
  Ok(env)
}

///|
pub fn prebind_templates(env : CompileEnv, nodes : Array[Node]) -> Unit {
  for node in nodes {
    match node {
      Def(name, params, body, _) => env.bind_template(name, params, body)
      _ => ()
    }
  }
}

///|
pub fn collect_scope_env(nodes : Array[Node], env : CompileEnv) -> CompileEnv {
  let local_env = env.copy()
  prebind_templates(local_env, nodes)
  local_env
}

///|
pub fn bind_template_call_env(
  template : Template,
  attrs : Array[Attr],
  children : Array[Node],
  call_env : CompileEnv,
  call_span : SourceSpan,
) -> Result[CompileEnv, Diagnostic] {
  template.bind_call({ attrs, children, span: call_span }, call_env)
}

///|
fn Template::bind_call(
  self : Template,
  call : TemplateCall,
  call_env : CompileEnv,
) -> Result[CompileEnv, Diagnostic] {
  self
  .resolve_call_values(call)
  .map(values => {
    let template_env = call_env.copy()
    template_env.append(self.env)
    for index in 0..<self.params.length() {
      template_env.bind_value(self.params[index], values[index])
    }
    template_env
  })
}

///|
fn Template::resolve_call_values(
  self : Template,
  call : TemplateCall,
) -> Result[Array[Value], Diagnostic] {
  let args = TemplateArguments::for_params(self.params)
  for attr in call.attrs {
    if args.bind_named(self.params, attr) is Err(error) {
      return Err(error)
    }
  }
  match args.bind_positional(self.params, positional_values(call.children)) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  args.finish(self.params, call.span)
}

///|
fn TemplateArguments::for_params(params : Array[String]) -> TemplateArguments {
  let values : Array[Value?] = []
  for _ in params {
    values.push(None)
  }
  { values, }
}

///|
fn TemplateArguments::bind_named(
  self : TemplateArguments,
  params : Array[String],
  attr : Attr,
) -> Result[Unit, Diagnostic] {
  guard attr.value is Some(value) else {
    return Err(
      attr.span.diagnostic(
        DiagnosticPhase::Template,
        "template argument requires a value: " + attr.name,
      ),
    )
  }
  guard param_index(params, attr.name) is Some(index) else {
    return Err(
      attr.span.diagnostic(
        DiagnosticPhase::Template,
        "unknown template argument: " + attr.name,
      ),
    )
  }
  if self.values[index] is Some(_) {
    return Err(
      attr.span.diagnostic(
        DiagnosticPhase::Template,
        "duplicate template argument: " + attr.name,
      ),
    )
  }
  self.values[index] = Some(value)
  Ok(())
}

///|
fn TemplateArguments::bind_positional(
  self : TemplateArguments,
  params : Array[String],
  positional : Array[Value],
) -> Result[Unit, Diagnostic] {
  let mut next_param = 0
  for arg in positional {
    let mut found_slot = false
    while next_param < self.values.length() && !found_slot {
      match self.values[next_param] {
        Some(_) => next_param += 1
        None => found_slot = true
      }
    }
    if next_param >= params.length() {
      return Err(
        arg
        .span()
        .diagnostic(DiagnosticPhase::Template, "too many template arguments"),
      )
    }
    self.values[next_param] = Some(arg)
    next_param += 1
  }
  Ok(())
}

///|
fn TemplateArguments::finish(
  self : TemplateArguments,
  params : Array[String],
  call_span : SourceSpan,
) -> Result[Array[Value], Diagnostic] {
  let bound : Array[Value] = []
  for index in 0..<params.length() {
    guard self.values[index] is Some(value) else {
      return Err(
        call_span.diagnostic(
          DiagnosticPhase::Template,
          "missing template argument: " + params[index],
        ),
      )
    }
    bound.push(value)
  }
  Ok(bound)
}

///|
fn positional_values(children : Array[Node]) -> Array[Value] {
  children.filter_map(child => {
    match child {
      Text(text, span) => text_arg_value(text, span)
      TextInterp(text, span) => Some(Value::Interp(text, span))
      Element("_", _, nodes, span) => Some(Value::Fragment(nodes, span))
      _ => Some(nodes_to_value([child]))
    }
  })
}

///|
fn text_arg_value(text : String, span : SourceSpan) -> Value? {
  let trimmed = text.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  Some(Value::Scalar(trimmed, span))
}

///|
fn param_index(params : Array[String], name : String) -> Int? {
  params.search_by(param => param == name)
}

///|
pub fn value_to_scalar(
  value : Value,
  env : CompileEnv,
) -> Result[String, Diagnostic] {
  match value {
    Scalar(text, _) => Ok(text)
    Bool(value, _) => Ok(if value { "true" } else { "false" })
    Interp(template, span) => interpolate_scalar(template, env, span)
    Fragment(_, span) =>
      Err(
        span.diagnostic(
          DiagnosticPhase::Type,
          "expected scalar value, but got rich content",
        ),
      )
  }
}

///|
pub fn interpolate_scalar(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
) -> Result[String, Diagnostic] {
  interpolate_text(template, env, span, value_to_scalar)
}

///|
pub fn interpolate_text(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
  value_to_text : (Value, CompileEnv) -> Result[String, Diagnostic],
) -> Result[String, Diagnostic] {
  let parts : Array[String] = []
  for part in template {
    let result = interpolation_part_text(part, env, span, value_to_text)
    if result is Ok(text) {
      parts.push(text)
    } else if result is Err(error) {
      return Err(error)
    }
  }
  Ok(parts.join(""))
}

///|
fn interpolation_part_text(
  part : InterpolationPart,
  env : CompileEnv,
  span : SourceSpan,
  value_to_text : (Value, CompileEnv) -> Result[String, Diagnostic],
) -> Result[String, Diagnostic] {
  match part {
    Literal(text) => Ok(text)
    Name(name) => {
      guard env.lookup_value(name) is Some(value) else {
        return Err(
          span.diagnostic(
            DiagnosticPhase::Binding,
            "unbound interpolation name: " + name,
          ),
        )
      }
      value_to_text(value, env)
    }
  }
}

///|
pub fn bool_binding(
  env : CompileEnv,
  name : String,
  span : SourceSpan,
) -> Result[Bool, Diagnostic] {
  match env.lookup_value(name) {
    Some(Bool(value, _)) => Ok(value)
    Some(Scalar("true", _)) => Ok(true)
    Some(Scalar("false", _)) => Ok(false)
    Some(_) =>
      Err(
        span.diagnostic(
          DiagnosticPhase::Type,
          "condition is not a boolean binding: " + name,
        ),
      )
    None =>
      Err(
        span.diagnostic(
          DiagnosticPhase::Binding,
          "unbound condition name: " + name,
        ),
      )
  }
}
