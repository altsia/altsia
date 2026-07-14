///|
priv struct UseDirective {
  target : String
  span : @core.SourceSpan
}

///|
fn leading_use_directives(doc : @core.Document) -> Array[UseDirective] {
  let uses : Array[UseDirective] = []
  for node in doc.nodes {
    match node {
      Element("use", _, children, span) =>
        if children.get(0).bind(node => @content.text_from_node(node))
          is Some(target) {
          uses.push({ target, span })
        }
      _ => return uses
    }
  }
  uses
}

///|
fn strip_leading_use_directives(doc : @core.Document) -> @core.Document {
  let nodes : Array[@core.Node] = []
  let mut in_prelude = true
  for node in doc.nodes {
    if in_prelude {
      match node {
        Element("use", _, _, _) => continue
        _ => in_prelude = false
      }
    }
    nodes.push(node)
  }
  { source: doc.source, nodes }
}

///|
fn collect_prefixed_library_env(
  module_name : String,
  doc : @core.Document,
  builtin_env : @core.CompileEnv,
) -> @core.CompileEnv {
  let options : @core.BindingCollectOptions = {
    include_doc: false,
    include_let: true,
    include_def: true,
  }
  let own = @core.collect_bindings(doc, options~)
  let collected = @core.collect_bindings(doc, base=builtin_env, options~)
  let env = @core.CompileEnv::empty()
  for name, _ in own.values {
    if collected.lookup_value(name) is Some(value) {
      env.bind_value("\{module_name}.\{name}", value)
    }
  }
  for name, _ in own.templates {
    if collected.lookup_template(name) is Some(template) {
      env.bind_template_value("\{module_name}.\{name}", template)
    }
  }
  env
}
