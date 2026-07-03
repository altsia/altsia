///|
priv struct CompileInput {
  root : String
  tree_order : Array[String]
  source_trees_by_slug : Map[String, @model.ParsedTree]
}

///|
priv struct ResolveState {
  input : CompileInput
  resolved_by_slug : Map[String, ResolvedTree]
  visiting : Set[String]
  active_stack : Array[String]
  effects : CompileEffects
}

///|
priv struct CompileEffects {
  diagnostics : Array[@core.Diagnostic]
  source_file_dependencies : Array[@model.SourceFileDependency]
  dangling_tree_links : Array[@model.DanglingTreeLink]
  tree_relations_by_slug : Map[String, TreeRelations]
}

///|
priv struct RenderState {
  input : CompileInput
  resolved_by_slug : Map[String, ResolvedTree]
  effects : CompileEffects
}

///|
priv enum ResolvedContent {
  ResolvedText(String, @core.SourceSpan)
  ResolvedElement(
    String,
    Array[@core.Attr],
    Array[ResolvedContent],
    @core.SourceSpan
  )
  ResolvedLink(ResolvedLink)
  ResolvedEmbed(@model.EmbedDirective, String, ResolvedTree)
}

///|
priv struct ResolvedRichContent {
  nodes : Array[ResolvedContent]
  wrap_inline_content : Bool
}

///|
priv enum ResolvedLinkLabel {
  LinkText(String)
  LinkResolvedContent(ResolvedRichContent)
  LinkFallbackText(String)
}

///|
priv struct ResolvedLink {
  source : String
  target : String
  slug : @model.TreeSlug?
  label : ResolvedLinkLabel
  span : @core.SourceSpan
}

///|
priv struct ResolvedTree {
  slug : @model.TreeSlug
  path : String
  metadata : @model.Metadata
  content : ResolvedRichContent
  references : Set[String]
}

///|
priv struct TreeRelations {
  parent : @model.TreeSlug?
  explicit_parent : Bool
  backlinks : Set[String]
}

///|
priv struct RenderCounter {
  values : Array[Int]
}

///|
priv struct PreviewRenderContext {
  options : @model.PreviewOptions
  tree_links : Array[@model.PreviewTreeLink]
  embeds : Array[@model.PreviewEmbed]
  assets : Array[@model.PreviewAsset]
  link_counter : Array[Int]
  embed_counter : Array[Int]
}

///|
fn CompileInput::new(
  root : String,
  parsed : Array[@model.ParsedTree],
) -> CompileInput {
  let tree_order : Array[String] = []
  let source_trees_by_slug : Map[String, @model.ParsedTree] = Map([])
  for tree in parsed {
    let key = tree.slug.canonical()
    tree_order.push(key)
    source_trees_by_slug[key] = tree
  }
  { root, tree_order, source_trees_by_slug }
}

///|
fn CompileEffects::new(parsed : Array[@model.ParsedTree]) -> CompileEffects {
  {
    diagnostics: [],
    source_file_dependencies: collect_initial_source_file_dependencies(parsed),
    dangling_tree_links: [],
    tree_relations_by_slug: Map([]),
  }
}

///|
fn ResolveState::new(
  input : CompileInput,
  parsed : Array[@model.ParsedTree],
) -> ResolveState {
  {
    input,
    resolved_by_slug: Map([]),
    visiting: Set([]),
    active_stack: [],
    effects: CompileEffects::new(parsed),
  }
}

///|
fn RenderState::new(
  input : CompileInput,
  resolved_by_slug : Map[String, ResolvedTree],
  effects : CompileEffects,
) -> RenderState {
  { input, resolved_by_slug, effects }
}

///|
fn PreviewRenderContext::new(
  options : @model.PreviewOptions,
) -> PreviewRenderContext {
  {
    options,
    tree_links: [],
    embeds: [],
    // TODO(altsia): populate this when PreviewOptions::collect_assets has a
    // concrete asset discovery contract.
    assets: [],
    link_counter: [0],
    embed_counter: [0],
  }
}

///|
fn PreviewRenderContext::next_link_id(self : PreviewRenderContext) -> String {
  let value = self.link_counter[0] + 1
  self.link_counter[0] = value
  "link-" + value.to_string()
}

///|
fn PreviewRenderContext::next_embed_id(self : PreviewRenderContext) -> String {
  let value = self.embed_counter[0] + 1
  self.embed_counter[0] = value
  "embed-" + value.to_string()
}

///|
fn RenderCounter::new() -> RenderCounter {
  { values: [0] }
}

///|
fn RenderCounter::next(self : RenderCounter) -> Int {
  let value = self.values[0] + 1
  self.values[0] = value
  value
}
