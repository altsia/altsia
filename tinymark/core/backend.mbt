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
pub(all) struct BindingCollectOptions {
  include_meta : Bool
  include_let : Bool
  include_def : Bool
}

///|
pub fn BindingCollectOptions::default() -> BindingCollectOptions {
  { include_meta: true, include_let: true, include_def: true }
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
// Scans in reverse so the most recently bound name wins (shadowing).
pub fn CompileEnv::lookup_value(self : CompileEnv, name : String) -> Value? {
  let env = self.bindings
  let mut index = env.length()
  while index > 0 {
    index -= 1
    let binding = env[index]
    if binding.name != name {
      continue
    }
    if binding.value is BoundValue(value) {
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
  let env = self.bindings
  let mut index = env.length()
  while index > 0 {
    index -= 1
    let binding = env[index]
    if binding.name != name {
      continue
    }
    if binding.value is BoundTemplate(template) {
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
pub fn CompileEnv::bind_meta_attr(self : CompileEnv, attr : Attr) -> Unit {
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
      Meta(attrs, _) if opts.include_meta =>
        for attr in attrs {
          env.bind_meta_attr(attr)
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
  template_call_values(template, attrs, children, call_span).map(values => {
    let template_env = call_env.copy()
    template_env.append(template.env)
    for index in 0..<template.params.length() {
      template_env.bind_value(template.params[index], values[index])
    }
    template_env
  })
}

///|
fn template_call_values(
  template : Template,
  attrs : Array[Attr],
  children : Array[Node],
  call_span : SourceSpan,
) -> Result[Array[Value], Diagnostic] {
  let values : Array[Value?] = []
  for _ in template.params {
    values.push(None)
  }
  for attr in attrs {
    if bind_named_template_arg(values, template.params, attr) is Err(error) {
      return Err(error)
    }
  }
  let mut next_param = 0
  for arg in positional_values(children) {
    let mut found_slot = false
    while next_param < values.length() && !found_slot {
      match values[next_param] {
        Some(_) => next_param += 1
        None => found_slot = true
      }
    }
    if next_param >= values.length() {
      return Err(
        arg
        .span()
        .diagnostic(DiagnosticPhase::Template, "too many template arguments"),
      )
    }
    values[next_param] = Some(arg)
    next_param += 1
  }
  let bound : Array[Value] = []
  for index in 0..<template.params.length() {
    guard values[index] is Some(value) else {
      return Err(
        call_span.diagnostic(
          DiagnosticPhase::Template,
          "missing template argument: " + template.params[index],
        ),
      )
    }
    bound.push(value)
  }
  Ok(bound)
}

///|
fn bind_named_template_arg(
  values : Array[Value?],
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
  if values[index] is Some(_) {
    return Err(
      attr.span.diagnostic(
        DiagnosticPhase::Template,
        "duplicate template argument: " + attr.name,
      ),
    )
  }
  values[index] = Some(value)
  Ok(())
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
