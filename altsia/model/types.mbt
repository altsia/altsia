///|
pub(all) struct SourceFile {
  path : String
  source : String
} derive(Eq, Debug)

///|
pub extend SourceFile with Eq::{not_equal, equal}

///|
pub extend SourceFile with Debug::{to_repr}

///|
pub(all) struct Project {
  workspace : @vfs.Workspace
  sources : Array[SourceFile]
} derive(Eq, Debug)

///|
pub extend Project with Eq::{not_equal, equal}

///|
pub extend Project with Debug::{to_repr}

///|
pub(all) struct EmbedOption {
  numbering : Bool
  details_open : Bool
  catalog : Bool
} derive(Eq, Debug)

///|
pub extend EmbedOption with Eq::{not_equal, equal}

///|
pub extend EmbedOption with Debug::{to_repr}

///|
pub fn EmbedOption::default() -> EmbedOption {
  { numbering: false, details_open: true, catalog: true }
}

///|
pub(all) struct LinkDirective {
  target : String
  text : String?
  span : @core.SourceSpan
}

///|
pub(all) struct EmbedDirective {
  target : String
  title : String?
  option : EmbedOption
  span : @core.SourceSpan
}

///|
pub(all) enum RichContentDirective {
  RichLinkDirective(LinkDirective)
  RichEmbedDirective(EmbedDirective)
}

///|
pub(all) enum RichContentNode {
  RichText(String, @core.SourceSpan)
  RichElement(
    String,
    Array[@core.Attr],
    Array[RichContentNode],
    @core.SourceSpan
  )
  RichDirective(RichContentDirective)
}

///|
pub(all) struct RichContent {
  nodes : Array[RichContentNode]
  wrap_inline_content : Bool
}

///|
pub(all) struct Metadata {
  slug : TreeSlug
  source_id : String
  lang : String?
  title : (RichContent, String)?
  page_title : String?
  taxon : Taxon?
  parent : TreeSlug?
  show_references : Bool
  show_backlinks : Bool
  asref : Bool
  asback : Bool
  footer_mode : String
  footer_sort_by : String?
}

///|
pub(all) struct ParsedTree {
  slug : TreeSlug
  path : String
  content : RichContent
  metadata : Metadata
  source_file_dependencies : Array[SourceFileDependency]
}

///|
pub(all) enum SourceFileDependencyKind {
  LibraryUse
  TreeLink
  TreeEmbed
} derive(Eq, Debug)

///|
pub extend SourceFileDependencyKind with Eq::{not_equal, equal}

///|
pub extend SourceFileDependencyKind with Debug::{to_repr}

///|
pub(all) struct SourceFileDependency {
  source : String
  target : String
  kind : SourceFileDependencyKind
} derive(Eq, Debug)

///|
pub extend SourceFileDependency with Eq::{not_equal, equal}

///|
pub extend SourceFileDependency with Debug::{to_repr}

///|
pub(all) struct DanglingTreeLink {
  source : String
  target : String
} derive(Eq, Debug)

///|
pub extend DanglingTreeLink with Eq::{not_equal, equal}

///|
pub extend DanglingTreeLink with Debug::{to_repr}

///|
pub(all) struct CompiledTree {
  slug : TreeSlug
  path : String
  html : String
  metadata : Metadata
  references : Array[TreeSlug]
  backlinks : Array[TreeSlug]
  parent : TreeSlug?
}

///|
pub(all) struct CompiledProject {
  root : String
  trees : Array[CompiledTree]
  diagnostics : Array[@core.Diagnostic]
  source_file_dependencies : Array[SourceFileDependency]
  dangling_tree_links : Array[DanglingTreeLink]
}

///|
pub(all) struct PreviewResult {
  html : String
  diagnostics : Array[@core.Diagnostic]
  source_file_dependencies : Array[SourceFileDependency]
  dangling_tree_links : Array[DanglingTreeLink]
  entry_tree_slug : TreeSlug
  title : String?
}

///|
// TODO(altsia): decide whether structured preview owns asset discovery or
// receives assets from a later project/filesystem layer.
pub(all) struct PreviewOptions {
  annotate_html : Bool
  collect_assets : Bool
} derive(Eq, Debug)

///|
pub extend PreviewOptions with Eq::{not_equal, equal}

///|
pub extend PreviewOptions with Debug::{to_repr}

///|
pub fn PreviewOptions::default() -> PreviewOptions {
  { annotate_html: true, collect_assets: true }
}

///|
pub(all) struct PreviewTreeLink {
  id : String
  source : String
  target : String
  target_source : String?
  target_slug : TreeSlug?
  href : String
  missing : Bool
} derive(Eq, Debug)

///|
pub extend PreviewTreeLink with Eq::{not_equal, equal}

///|
pub extend PreviewTreeLink with Debug::{to_repr}

///|
pub(all) struct PreviewEmbed {
  id : String
  source : String
  target : String
  target_source : String
  target_slug : TreeSlug
  open : Bool
} derive(Eq, Debug)

///|
pub extend PreviewEmbed with Eq::{not_equal, equal}

///|
pub extend PreviewEmbed with Debug::{to_repr}

///|
// TODO(altsia): define the supported asset sources before relying on this
// public shape; it is currently reserved for structured preview output.
pub(all) struct PreviewAsset {
  id : String
  source : String
  attr : String
  target : String
  resolved_path : String?
  kind : String
} derive(Eq, Debug)

///|
pub extend PreviewAsset with Eq::{not_equal, equal}

///|
pub extend PreviewAsset with Debug::{to_repr}

///|
pub(all) struct StructuredPreview {
  html : String
  entry : String
  entry_tree_slug : TreeSlug
  title : String?
  diagnostics : Array[@core.Diagnostic]
  source_file_dependencies : Array[SourceFileDependency]
  dangling_tree_links : Array[DanglingTreeLink]
  tree_links : Array[PreviewTreeLink]
  embeds : Array[PreviewEmbed]
  assets : Array[PreviewAsset]
}

///|
pub fn Project::new(root : String, sources : Array[SourceFile]) -> Project {
  { workspace: @vfs.Workspace::new(root), sources }
}

///|
pub fn CompiledTree::title(self : CompiledTree) -> String {
  match self.metadata.page_title {
    Some(value) => value
    None =>
      self.metadata.title.map(title => title.1).unwrap_or(self.slug.canonical())
  }
}

///|
pub fn CompiledTree::page_title(self : CompiledTree) -> String? {
  match self.metadata.page_title {
    Some(value) => Some(value)
    None => self.metadata.title.map(title => title.1)
  }
}

///|
pub fn CompiledProject::find_tree(
  self : CompiledProject,
  slug : TreeSlug,
) -> CompiledTree? {
  let key = slug.canonical()
  for tree in self.trees {
    if tree.slug.canonical() == key {
      return Some(tree)
    }
  }
  None
}
