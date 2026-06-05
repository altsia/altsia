///|
type LinkDirective = @model.LinkDirective

///|
type EmbedDirective = @model.EmbedDirective

///|
type RichContentDirective = @model.RichContentDirective

///|
type RichContent = @model.RichContent

///|
type Metadata = @model.Metadata

///|
type ParsedTree = @model.ParsedTree

///|
type SourceFileDependency = @model.SourceFileDependency

///|
type SourceFileDependencyKind = @model.SourceFileDependencyKind

///|
type DanglingTreeLink = @model.DanglingTreeLink

///|
type CompiledTree = @model.CompiledTree

///|
type CompiledProject = @model.CompiledProject

///|
type TreeSlug = @model.TreeSlug

///|
fn has_suffix(text : String, suffix : String) -> Bool {
  @model.has_suffix(text, suffix)
}

///|
fn normalize_path(path : String) -> String {
  @model.normalize_path(path)
}

///|
fn tree_slug_from_target(current_path : String, target : String) -> TreeSlug {
  @model.tree_slug_from_target(current_path, target)
}

///|
fn url_for_tree(slug : TreeSlug) -> String {
  @model.url_for_tree(slug)
}

///|
fn tree_title(tree : CompiledTree) -> String {
  @model.tree_title(tree)
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
