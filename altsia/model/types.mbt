///|
pub enum SourceFileKind {
  AltDocument
  AltLibrary
} derive(Eq, Debug)

///|
pub(all) struct SourceFile {
  path : String
  source : String
} derive(Eq, Debug)

///|
pub(all) struct Project {
  root : String
  sources : Array[SourceFile]
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
pub(all) struct SourceFileDependency {
  source : String
  target : String
  kind : SourceFileDependencyKind
} derive(Eq, Debug)

///|
pub(all) struct DanglingTreeLink {
  source : String
  target : String
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
pub(all) struct PreviewOptions {
  annotate_html : Bool
  collect_assets : Bool
} derive(Eq, Debug)

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
pub(all) struct PreviewEmbed {
  id : String
  source : String
  target : String
  target_source : String
  target_slug : TreeSlug
  open : Bool
} derive(Eq, Debug)

///|
pub(all) struct PreviewAsset {
  id : String
  source : String
  attr : String
  target : String
  resolved_path : String?
  kind : String
} derive(Eq, Debug)

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
  { root, sources }
}

///|
pub fn tree_title(tree : CompiledTree) -> String {
  match tree.metadata.page_title {
    Some(value) => value
    None =>
      tree.metadata.title.map(title => title.1).unwrap_or(tree.slug.canonical())
  }
}

///|
pub fn tree_page_title(tree : CompiledTree) -> String? {
  match tree.metadata.page_title {
    Some(value) => Some(value)
    None => tree.metadata.title.map(title => title.1)
  }
}

///|
pub fn compiled_tree_by_slug(
  project : CompiledProject,
  slug : TreeSlug,
) -> CompiledTree? {
  let key = slug.canonical()
  for tree in project.trees {
    if tree.slug.canonical() == key {
      return Some(tree)
    }
  }
  None
}
