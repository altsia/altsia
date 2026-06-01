///|
pub enum SourceKind {
  Alt
  Sia
} derive(Eq, Debug)

///|
pub(all) struct SourceFile {
  path : String
  source : String
} derive(Eq, Debug)

///|
pub(all) struct ProjectConfig {
  root : String
  config_path : String
} derive(Eq, Debug)

///|
pub(all) struct Project {
  root : String
  sources : Array[SourceFile]
} derive(Eq, Debug)

///|
pub(all) struct ProjectSnapshot {
  root : String
  sources : Array[SourceFile]
  open_file : String?
} derive(Eq, Debug)

///|
pub(all) struct EmbedOption {
  numbering : Bool
  details_open : Bool
  catalog : Bool
} derive(Eq, Debug)

///|
pub fn EmbedOption::default() -> EmbedOption {
  { numbering: false, details_open: true, catalog: true }
}

///|
pub(all) struct LinkContent {
  target : String
  text : String?
  span : @core.SourceSpan
}

///|
pub(all) struct EmbedContent {
  target : String
  title : String?
  option : EmbedOption
  span : @core.SourceSpan
}

///|
pub enum CompiledContentChunk {
  HtmlChunk(String)
  LocalLinkChunk(LinkContent)
  EmbedChunk(EmbedContent)
}

///|
pub type CompiledContent = Array[CompiledContentChunk]

///|
pub(all) struct Metadata {
  slug : TreeSlug
  source_id : String
  lang : String?
  title : String?
  page_title : String?
  taxon : Taxon?
  parent : TreeSlug?
  show_references : Bool
  show_backlinks : Bool
  asref : Bool
  asback : Bool
  footer_mode : String
  footer_sort_by : String?
} derive(Eq, Debug)

///|
pub(all) struct UnresolvedTree {
  slug : TreeSlug
  path : String
  doc : @core.Document
  env : @core.CompileEnv
  metadata : Metadata
  dependencies : Array[SourceDependency]
}

///|
pub(all) enum DependencyKind {
  UseLibrary
  LocalLink
  Embed
} derive(Eq, Debug)

///|
pub(all) struct SourceDependency {
  source : String
  target : String
  kind : DependencyKind
} derive(Eq, Debug)

///|
pub(all) struct MissingTarget {
  source : String
  target : String
  kind : DependencyKind
} derive(Eq, Debug)

///|
pub(all) struct CompiledTree {
  slug : TreeSlug
  path : String
  html : String
  metadata : Metadata
  references : Array[TreeSlug]
  backlinks : Array[TreeSlug]
  parent : TreeSlug?
} derive(Debug)

///|
pub(all) struct CompiledProject {
  root : String
  trees : Array[CompiledTree]
  trees_by_slug : Map[String, CompiledTree]
  diagnostics : Array[@core.Diagnostic]
  dependencies : Array[SourceDependency]
  missing_targets : Array[MissingTarget]
}

///|
pub(all) struct PreviewResult {
  html : String
  diagnostics : Array[@core.Diagnostic]
  dependencies : Array[SourceDependency]
  missing_targets : Array[MissingTarget]
  entry_tree_slug : TreeSlug
  title : String?
}
