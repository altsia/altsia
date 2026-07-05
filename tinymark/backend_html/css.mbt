pub type CSS

///|
pub fn CSS::compile_rule_nodes(
  children : Array[@core.Node],
  scope : String?,
  env : @core.CompileEnv,
) -> Result[Array[String], @core.Diagnostic] {
  let rules : Array[String] = []
  for child in children {
    let result = compile_css_rule_node(child, scope, env)
    if result is Ok(Some(rule)) {
      rules.push(rule)
    }
    if result is Err(error) {
      return Err(error)
    }
  }
  Ok(rules)
}

///|
fn compile_css_rule_node(
  node : @core.Node,
  scope : String?,
  env : @core.CompileEnv,
) -> Result[String?, @core.Diagnostic] {
  match node {
    Element(tag, attrs, children, span) =>
      compile_css_rule_element(tag, attrs, children, scope, env, span)
    Text(text, _) if text.trim().is_empty() => Ok(None)
    _ =>
      Err(
        node
        .span()
        .diagnostic(
          @core.DiagnosticPhase::ContentModel,
          "style only accepts css rule elements",
        ),
      )
  }
}

///|
fn compile_css_rule_element(
  tag : String,
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  scope : String?,
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[String?, @core.Diagnostic] {
  if !children.is_empty() {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        "style rules only accept declaration attributes",
      ),
    )
  }
  compile_css_rule(tag, attrs, scope, env, span).map(rule => Some(rule))
}

///|
pub fn CSS::normalize_css_scope(scope : String) -> String {
  let trimmed = scope.trim().to_owned()
  if is_explicit_css_scope_selector(trimmed) {
    return trimmed
  }
  "." + trimmed
}

///|
fn is_explicit_css_scope_selector(selector : String) -> Bool {
  [".", "#", "[", ":", "*"].any(prefix => selector.has_prefix(prefix))
}

///|
fn compile_css_rule(
  tag : String,
  attrs : Array[@core.Attr],
  scope : String?,
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[String, @core.Diagnostic] {
  scope_css_selector(tag, scope, span).bind(sel => {
    compile_css_declarations(attrs, env).map(decls => sel + "{" + decls + "}")
  })
}

///|
fn compile_css_declarations(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Result[String, @core.Diagnostic] {
  let declarations : Array[String] = []
  for attr in attrs {
    match compile_css_declaration(attr, env) {
      Ok(declaration) => declarations.push(declaration)
      Err(error) => return Err(error)
    }
  }
  Ok(declarations.join(""))
}

///|
fn compile_css_declaration(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> Result[String, @core.Diagnostic] {
  match attr.value {
    Some(value) =>
      value.to_scalar(env).map(text => attr.name + ":" + text + ";")
    None =>
      Err(
        attr.span.diagnostic(
          @core.DiagnosticPhase::Type,
          "css declaration requires a value: " + attr.name,
        ),
      )
  }
}

///|
fn scope_css_selector(
  selector : String,
  scope : String?,
  span : @core.SourceSpan,
) -> Result[String, @core.Diagnostic] {
  let trimmed = selector.trim().to_owned()
  if trimmed.is_empty() {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        "css selector cannot be empty",
      ),
    )
  }
  if is_css_selector_list(trimmed) {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        "css selector lists are not supported; write separate rules",
      ),
    )
  }
  if scope is Some(scope_selector) {
    if css_selector_uses_scope_marker(trimmed) {
      return Ok(trimmed.replace_all(old="&", new=scope_selector))
    }
    return Ok(scope_selector + " " + trimmed)
  }
  if css_selector_uses_scope_marker(trimmed) {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        "css selector '&' requires a style scope",
      ),
    )
  }
  Ok(trimmed)
}

///|
fn is_css_selector_list(selector : String) -> Bool {
  selector.contains(",")
}

///|
fn css_selector_uses_scope_marker(selector : String) -> Bool {
  selector.contains("&")
}
