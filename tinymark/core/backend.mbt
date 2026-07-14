///|
pub(all) struct CompileEnv {
  values : Map[String, Value]
  templates : Map[String, Template]
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
  indexes : Map[String, Int]
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
  { values: Map([]), templates: Map([]) }
}

///|
pub fn CompileEnv::copy(self : CompileEnv) -> CompileEnv {
  { values: self.values.copy(), templates: self.templates.copy() }
}

///|
pub fn CompileEnv::append(self : CompileEnv, other : CompileEnv) -> Unit {
  for name, value in other.values {
    self.values[name] = value
  }
  for name, template in other.templates {
    self.templates[name] = template
  }
}

///|
pub fn CompileEnv::lookup_value(self : CompileEnv, name : String) -> Value? {
  self.values.get(name)
}

///|
pub fn CompileEnv::bind_value(
  self : CompileEnv,
  name : String,
  value : Value,
) -> Unit {
  self.values[name] = value
}

///|
pub fn CompileEnv::lookup_template(
  self : CompileEnv,
  name : String,
) -> Template? {
  self.templates.get(name)
}

///|
pub fn CompileEnv::bind_template(
  self : CompileEnv,
  name : String,
  params : Array[String],
  body : Array[Node],
) -> Unit {
  self.templates[name] = { params, body, env: self.copy() }
}

///|
pub fn CompileEnv::bind_template_value(
  self : CompileEnv,
  name : String,
  template : Template,
) -> Unit {
  self.templates[name] = template
}

///|
pub fn CompileEnv::bind_doc_attr(self : CompileEnv, attr : Attr) -> Unit {
  if attr.value is Some(value) {
    self.bind_value(attr.name, value)
  }
}

///|
pub fn CompileEnv::bind_scope_node(
  self : CompileEnv,
  node : Node,
  on_doc_attr : (Attr) -> Unit,
) -> Bool {
  match node {
    Let(name, value, _) => {
      self.bind_value(name, value)
      true
    }
    Def(name, params, body, _) => {
      self.bind_template(name, params, body)
      true
    }
    Doc(attrs, _) => {
      for attr in attrs {
        on_doc_attr(attr)
        self.bind_doc_attr(attr)
      }
      true
    }
    _ => false
  }
}

///|
pub fn visit_scoped_nodes(
  nodes : Array[Node],
  env : CompileEnv,
  on_doc_attr : (Attr) -> Unit,
  visit : (Node, CompileEnv) -> Unit raise Diagnostic,
) -> CompileEnv raise Diagnostic {
  let local_env = collect_scope_env(nodes, env)
  for node in nodes {
    if !local_env.bind_scope_node(node, on_doc_attr) {
      visit(node, local_env)
    }
  }
  local_env
}

///|
pub fn collect_bindings(
  doc : Document,
  base? : CompileEnv,
  options? : BindingCollectOptions,
) -> CompileEnv {
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
  env
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
) -> CompileEnv raise Diagnostic {
  template.bind_call({ attrs, children, span: call_span }, call_env)
}

///|
fn Template::bind_call(
  self : Template,
  call : TemplateCall,
  call_env : CompileEnv,
) -> CompileEnv raise Diagnostic {
  let values = self.resolve_call_values(call)
  let template_env = call_env.copy()
  template_env.append(self.env)
  for index in 0..<self.params.length() {
    template_env.bind_value(self.params[index], values[index])
  }
  template_env
}

///|
fn Template::resolve_call_values(
  self : Template,
  call : TemplateCall,
) -> Array[Value] raise Diagnostic {
  let args = TemplateArguments::for_params(self.params)
  for attr in call.attrs {
    args.bind_named(attr)
  }
  args.bind_positional(self.params, positional_values(call.children))
  args.finish(self.params, call.span)
}

///|
fn TemplateArguments::for_params(params : Array[String]) -> TemplateArguments {
  let indexes : Map[String, Int] = Map([])
  for index, name in params {
    indexes[name] = index
  }
  { values: Array::make(params.length(), None), indexes }
}

///|
fn TemplateArguments::bind_named(
  self : TemplateArguments,
  attr : Attr,
) -> Unit raise Diagnostic {
  guard attr.value is Some(value) else {
    raise attr.span.diagnostic(
      DiagnosticPhase::Template,
      "template argument requires a value: " + attr.name,
    )
  }
  guard self.indexes.get(attr.name) is Some(index) else {
    raise attr.span.diagnostic(
      DiagnosticPhase::Template,
      "unknown template argument: " + attr.name,
    )
  }
  if self.values[index] is Some(_) {
    raise attr.span.diagnostic(
      DiagnosticPhase::Template,
      "duplicate template argument: " + attr.name,
    )
  }
  self.values[index] = Some(value)
}

///|
fn TemplateArguments::bind_positional(
  self : TemplateArguments,
  params : Array[String],
  positional : Array[Value],
) -> Unit raise Diagnostic {
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
      raise arg
        .span()
        .diagnostic(DiagnosticPhase::Template, "too many template arguments")
    }
    self.values[next_param] = Some(arg)
    next_param += 1
  }
}

///|
fn TemplateArguments::finish(
  self : TemplateArguments,
  params : Array[String],
  call_span : SourceSpan,
) -> Array[Value] raise Diagnostic {
  let bound : Array[Value] = []
  for index in 0..<params.length() {
    guard self.values[index] is Some(value) else {
      raise call_span.diagnostic(
        DiagnosticPhase::Template,
        "missing template argument: " + params[index],
      )
    }
    bound.push(value)
  }
  bound
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
  Some(Value::Scalar(Text(trimmed), span))
}

///|
pub fn interpolate_scalar(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
) -> String raise Diagnostic {
  interpolate_text(template, env, span, (value, env) => value.to_scalar(env))
}

///|
pub fn Value::to_bool(
  self : Value,
  context_span : SourceSpan,
  message : String,
) -> Bool raise Diagnostic {
  match self {
    Scalar(Bool(value), _) => value
    _ => raise context_span.diagnostic(DiagnosticPhase::Type, message)
  }
}

///|
pub fn interpolate_text(
  template : Interpolation,
  env : CompileEnv,
  span : SourceSpan,
  value_to_text : (Value, CompileEnv) -> String raise Diagnostic,
) -> String raise Diagnostic {
  let rendered = StringBuilder()
  for part in template {
    rendered.write_string(
      interpolation_part_text(part, env, span, value_to_text),
    )
  }
  rendered.to_string()
}

///|
fn interpolation_part_text(
  part : InterpolationPart,
  env : CompileEnv,
  span : SourceSpan,
  value_to_text : (Value, CompileEnv) -> String raise Diagnostic,
) -> String raise Diagnostic {
  match part {
    Literal(text) => text
    Name(name) => {
      guard env.lookup_value(name) is Some(value) else {
        raise span.diagnostic(
          DiagnosticPhase::Binding,
          "unbound interpolation name: " + name,
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
) -> Bool raise Diagnostic {
  match env.lookup_value(name) {
    Some(value) =>
      value.to_bool(span, "condition is not a boolean binding: " + name)
    None =>
      raise span.diagnostic(
        DiagnosticPhase::Binding,
        "unbound condition name: " + name,
      )
  }
}
