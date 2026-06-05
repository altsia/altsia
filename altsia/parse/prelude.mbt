///|
type SourceFileKind = @model.SourceFileKind

///|
type SourceFile = @model.SourceFile

///|
type Project = @model.Project

///|
type RichContent = @model.RichContent

///|
type Metadata = @model.Metadata

///|
type ParsedTree = @model.ParsedTree

///|
type SourceFileDependency = @model.SourceFileDependency

///|
type TreeSlug = @model.TreeSlug

///|
type Taxon = @model.Taxon

///|
fn has_suffix(text : String, suffix : String) -> Bool {
  @model.has_suffix(text, suffix)
}

///|
fn normalize_path(path : String) -> String {
  @model.normalize_path(path)
}

///|
fn source_file_kind(path : String) -> SourceFileKind? {
  @model.source_file_kind(path)
}

///|
fn resolve_relative(current_path : String, target : String) -> String {
  @model.resolve_relative(current_path, target)
}

///|
fn module_name_from_path(path : String) -> String {
  @model.module_name_from_path(path)
}

///|
fn tree_slug_from_path(path : String) -> TreeSlug {
  @model.tree_slug_from_path(path)
}

///|
fn child_tree_slug(top_level_slug : TreeSlug, child_slug : String) -> TreeSlug {
  @model.child_tree_slug(top_level_slug, child_slug)
}

///|
fn anonymous_tree_anchor(top_level_slug : TreeSlug, index : Int) -> String {
  @model.anonymous_tree_anchor(top_level_slug, index)
}

///|
fn diagnostic(
  span : @core.SourceSpan,
  phase : @core.DiagnosticPhase,
  message : String,
  hint? : String,
) -> @core.Diagnostic {
  match hint {
    Some(hint) => @model.diagnostic(span, phase, message, hint~)
    None => @model.diagnostic(span, phase, message)
  }
}

///|
fn source_diagnostic(
  source_id : String,
  phase : @core.DiagnosticPhase,
  message : String,
  hint? : String,
) -> @core.Diagnostic {
  match hint {
    Some(hint) => @model.source_diagnostic(source_id, phase, message, hint~)
    None => @model.source_diagnostic(source_id, phase, message)
  }
}

///|
fn compile_rich_content(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[RichContent, @core.Diagnostic] {
  match env {
    Some(env) => @content.compile_rich_content(doc, env~)
    None => @content.compile_rich_content(doc)
  }
}

///|
fn compile_inline_rich_content(
  doc : @core.Document,
  env : @core.CompileEnv,
) -> Result[RichContent, @core.Diagnostic] {
  @content.compile_inline_rich_content(doc, env)
}

///|
fn text_from_node(node : @core.Node, env? : @core.CompileEnv) -> String? {
  match env {
    Some(env) => @content.text_from_node(node, env~)
    None => @content.text_from_node(node)
  }
}
