///|
priv struct UseDirective {
  target : String
  span : @core.SourceSpan
}

///|
fn text_from_node(node : @core.Node) -> String? {
  match node {
    Text(text, _) | TextInterp(text, _) => Some(text)
    _ => None
  }
}

///|
fn use_target(children : Array[@core.Node]) -> String? {
  if children.length() == 0 {
    None
  } else {
    text_from_node(children[0])
  }
}

///|
fn leading_use_directives(doc : @core.Document) -> Array[UseDirective] {
  let uses : Array[UseDirective] = []
  for node in doc.nodes {
    match node {
      Element("use", _, children, span) =>
        match use_target(children) {
          Some(target) => uses.push({ target, span })
          None => ()
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
) -> Result[@core.CompileEnv, @core.Diagnostic] {
  let options : @core.BindingCollectOptions = {
    include_meta: false,
    include_let: true,
    include_def: true,
  }
  match @core.collect_bindings(doc, base=builtin_env, options~) {
    Err(error) => Err(error)
    Ok(collected) => {
      let env = @core.CompileEnv::empty()
      let base_count = builtin_env.bindings.length()
      for i in base_count..<collected.bindings.length() {
        let binding = collected.bindings[i]
        env.bindings.push({
          name: module_name + "." + binding.name,
          value: binding.value,
        })
      }
      Ok(env)
    }
  }
}
