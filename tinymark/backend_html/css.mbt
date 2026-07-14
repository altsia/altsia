///|
pub type CSS

///|
pub fn CSS::compile_rule_nodes(
  children : Array[@core.Node],
  scope : String?,
  env : @core.CompileEnv,
) -> Array[String] raise @core.Diagnostic {
  let rules : Array[String] = []
  for child in children {
    if compile_css_rule_node(child, scope, env) is Some(rule) {
      rules.push(rule)
    }
  }
  rules
}

///|
fn compile_css_rule_node(
  node : @core.Node,
  scope : String?,
  env : @core.CompileEnv,
) -> String? raise @core.Diagnostic {
  match node {
    Element(tag, attrs, children, span) =>
      compile_css_rule_element(tag, attrs, children, scope, env, span)
    Text(text, _) if text.trim().is_empty() => None
    _ =>
      raise node
        .span()
        .diagnostic(
          @core.DiagnosticPhase::ContentModel,
          "style only accepts css rule elements",
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
) -> String? raise @core.Diagnostic {
  if !children.is_empty() {
    raise span.diagnostic(
      @core.DiagnosticPhase::ContentModel,
      "style rules only accept declaration attributes",
    )
  }
  Some(compile_css_rule(tag, attrs, scope, env, span))
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
) -> String raise @core.Diagnostic {
  let selector = scope_css_selector(tag, scope, span)
  let rule = StringBuilder()
  rule <+ "\{selector}{"
  rule.write_string(compile_css_declarations(attrs, env))
  rule <+ "}"
  rule.to_string()
}

///|
fn compile_css_declarations(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> String raise @core.Diagnostic {
  let declarations = StringBuilder()
  for attr in attrs {
    declarations.write_string(compile_css_declaration(attr, env))
  }
  declarations.to_string()
}

///|
fn compile_css_declaration(
  attr : @core.Attr,
  env : @core.CompileEnv,
) -> String raise @core.Diagnostic {
  match attr.value {
    Some(value) => "\{attr.name}:\{value.to_scalar(env)};"
    None =>
      raise attr.span.diagnostic(
        @core.DiagnosticPhase::Type,
        "css declaration requires a value: " + attr.name,
      )
  }
}

///|
fn scope_css_selector(
  selector : String,
  scope : String?,
  span : @core.SourceSpan,
) -> String raise @core.Diagnostic {
  let trimmed = selector.trim().to_owned()
  if trimmed.is_empty() {
    raise span.diagnostic(
      @core.DiagnosticPhase::ContentModel,
      "css selector cannot be empty",
    )
  }
  if is_css_selector_list(trimmed) {
    raise span.diagnostic(
      @core.DiagnosticPhase::ContentModel,
      "css selector lists are not supported; write separate rules",
    )
  }
  if scope is Some(scope_selector) {
    if css_selector_uses_scope_marker(trimmed) {
      return trimmed.replace_all(old="&", new=scope_selector)
    }
    return "\{scope_selector} \{trimmed}"
  }
  if css_selector_uses_scope_marker(trimmed) {
    raise span.diagnostic(
      @core.DiagnosticPhase::ContentModel,
      "css selector '&' requires a style scope",
    )
  }
  trimmed
}

///|
fn is_css_selector_list(selector : String) -> Bool {
  selector.contains(",")
}

///|
fn css_selector_uses_scope_marker(selector : String) -> Bool {
  selector.contains("&")
}
