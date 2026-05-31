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
pub(all) struct SectionOption {
  numbering : Bool
  details_open : Bool
  catalog : Bool
} derive(Eq, Debug)

///|
pub fn SectionOption::default() -> SectionOption {
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
  option : SectionOption
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
  section_id : String
  source_id : String
  title : String?
  page_title : String?
  taxon : String?
  parent : String?
  show_references : Bool
  show_backlinks : Bool
  asref : Bool
  asback : Bool
  footer_mode : String
  footer_sort_by : String?
  internal_anon_section : Bool
} derive(Eq, Debug)

///|
pub(all) struct UnresolvedSection {
  id : String
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
pub(all) struct CompiledSection {
  id : String
  path : String
  html : String
  metadata : Metadata
  references : Array[String]
  backlinks : Array[String]
  parent : String?
} derive(Debug)

///|
pub(all) struct CompiledProject {
  root : String
  sections : Array[CompiledSection]
  sections_by_id : Map[String, CompiledSection]
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
  entry_section_id : String
  title : String?
}
