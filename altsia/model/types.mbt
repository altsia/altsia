///|
pub enum SourceFileKind {
  Alt
  Sia
} derive(Eq, Debug)

///|
pub(all) struct SourceFile {
  path : String
  source : String
} derive(Eq, Debug)

///|
pub(all) struct ProjectRoot {
  root : String
  config_path : String
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
pub(all) enum RichContentChunk {
  HtmlChunk(String)
  DirectiveChunk(RichContentDirective)
}

///|
pub type RichContent = Array[RichContentChunk]

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
