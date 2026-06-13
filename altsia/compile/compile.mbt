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
pub fn compile_parsed_project(
  root : String,
  parsed : Array[@model.ParsedTree],
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  let input = CompileInput::new(root, parsed)
  ResolveState::new(input, parsed).compile_all()
}

///|
pub fn compile_structured_preview(
  root : String,
  parsed : Array[@model.ParsedTree],
  entry_path : String,
  options : @model.PreviewOptions,
) -> Result[@model.StructuredPreview, @core.Diagnostic] {
  let input = CompileInput::new(root, parsed)
  let resolver = ResolveState::new(input, parsed)
  if resolver.input.source_trees_by_slug.contains("index") {
    match resolver.compile_resolved_tree("index") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for slug in resolver.input.tree_order {
    match resolver.compile_resolved_tree(slug) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  RenderState::new(resolver.input, resolver.resolved_by_slug, resolver.effects).render_structured_preview(
    entry_path, options,
  )
}

///|
fn ResolveState::compile_all(
  self : ResolveState,
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  if self.input.source_trees_by_slug.contains("index") {
    match self.compile_resolved_tree("index") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  for slug in self.input.tree_order {
    match self.compile_resolved_tree(slug) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  RenderState::new(self.input, self.resolved_by_slug, self.effects).render_project()
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
fn RenderState::render_project(
  self : RenderState,
) -> Result[@model.CompiledProject, @core.Diagnostic] {
  let compiled_tree_index = match self.compiled_tree_index() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    root: self.input.root,
    trees: self.ordered_compiled_trees(compiled_tree_index),
    diagnostics: self.effects.diagnostics,
    source_file_dependencies: self.effects.source_file_dependencies,
    dangling_tree_links: self.effects.dangling_tree_links,
  })
}

///|
fn collect_initial_source_file_dependencies(
  parsed : Array[@model.ParsedTree],
) -> Array[@model.SourceFileDependency] {
  let source_file_dependencies : Array[@model.SourceFileDependency] = []
  for tree in parsed {
    for dependency in tree.source_file_dependencies {
      if !source_file_dependencies.contains(dependency) {
        source_file_dependencies.push(dependency)
      }
    }
  }
  source_file_dependencies
}

///|
fn ResolveState::find_parsed(
  self : ResolveState,
  slug : String,
) -> @model.ParsedTree? {
  self.input.source_trees_by_slug.get(slug)
}

///|
fn ResolveState::find_resolved(
  self : ResolveState,
  slug : String,
) -> ResolvedTree? {
  self.resolved_by_slug.get(slug)
}

///|
fn ResolveState::compile_resolved_tree(
  self : ResolveState,
  slug : String,
) -> Result[ResolvedTree, @core.Diagnostic] {
  match self.find_resolved(slug) {
    Some(tree) => return Ok(tree)
    None => ()
  }
  if self.visiting.contains(slug) {
    return Err(self.cycle_diagnostic(slug))
  }
  let tree = match self.find_parsed(slug) {
    Some(value) => value
    None =>
      return Err(
        @model.source_diagnostic(slug, Binding, "missing tree: " + slug),
      )
  }
  self.visiting.add(slug)
  self.active_stack.push(slug)
  let result = self.resolve_tree_content(tree)
  let _ = self.active_stack.pop()
  self.visiting.remove(slug)
  let resolved = match result {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (contents, references) = resolved
  let compiled : ResolvedTree = {
    slug: tree.slug,
    path: tree.path,
    metadata: tree.metadata,
    content: contents,
    references,
  }
  match tree.metadata.parent {
    Some(parent) => self.specify_parent(slug, parent)
    None => ()
  }
  self.resolved_by_slug[slug] = compiled
  Ok(compiled)
}

///|
fn ResolveState::cycle_diagnostic(
  self : ResolveState,
  slug : String,
) -> @core.Diagnostic {
  let chain = self.active_stack.join(" -> ") + " -> " + slug
  @model.source_diagnostic(slug, Binding, "cyclic embed", hint=chain)
}

///|
fn ResolveState::resolve_tree_content(
  self : ResolveState,
  tree : @model.ParsedTree,
) -> Result[(ResolvedRichContent, Set[String]), @core.Diagnostic] {
  self.resolve_rich_content(tree.content, tree.slug.canonical(), tree.path)
}

///|
fn ResolveState::resolve_rich_content(
  self : ResolveState,
  content : @model.RichContent,
  source_slug : String,
  source_path : String,
) -> Result[(ResolvedRichContent, Set[String]), @core.Diagnostic] {
  let nodes : Array[ResolvedContent] = []
  let references : Set[String] = Set([])
  for node in content.nodes {
    match
      self.resolve_rich_content_node(node, source_slug, source_path, references) {
      Ok(content) => nodes.push(content)
      Err(error) => return Err(error)
    }
  }
  Ok(({ nodes, wrap_inline_content: content.wrap_inline_content }, references))
}

///|
fn ResolveState::resolve_rich_content_node(
  self : ResolveState,
  node : @model.RichContentNode,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  match node {
    @model.RichText(text, span) => Ok(ResolvedText(text, span))
    @model.RichElement(tag, attrs, children, span) => {
      let resolved_children : Array[ResolvedContent] = []
      for child in children {
        match
          self.resolve_rich_content_node(
            child, source_slug, source_path, references,
          ) {
          Ok(resolved) => resolved_children.push(resolved)
          Err(error) => return Err(error)
        }
      }
      Ok(ResolvedElement(tag, attrs, resolved_children, span))
    }
    @model.RichDirective(directive) =>
      self.resolve_rich_content_directive(
        directive, source_slug, source_path, references,
      )
  }
}

///|
fn ResolveState::resolve_rich_content_directive(
  self : ResolveState,
  directive : @model.RichContentDirective,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  match directive {
    @model.RichLinkDirective(link) =>
      self.resolve_link_directive(link, source_slug, source_path, references)
    @model.RichEmbedDirective(embed) =>
      self.resolve_embed_directive(embed, source_slug, source_path, references)
  }
}

///|
fn ResolveState::resolve_link_directive(
  self : ResolveState,
  link : @model.LinkDirective,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  let target = link.target
  match validate_tree_target(target, link.span, "link") {
    Some(error) => return Err(error)
    None => ()
  }
  let resolved_slug = @model.tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      self.add_dependency(source_path, target_tree.path, @model.TreeLink)
      match self.find_parsed(source_slug) {
        Some(source_tree) => {
          if target_tree.metadata.asref && source_slug != resolved_key {
            references.add(resolved_key)
          }
          if source_tree.metadata.asback && source_slug != resolved_key {
            self.insert_backlink(resolved_key, source_tree.slug.canonical())
          }
        }
        None => ()
      }
      let title = match link.text {
        Some(value) => LinkText(value)
        None =>
          match self.compile_resolved_tree(resolved_key) {
            Ok(tree) => self.resolve_link_fallback_label(tree, resolved_key)
            Err(_) => LinkFallbackText(resolved_key)
          }
      }
      Ok(
        ResolvedLink({
          source: source_path,
          target,
          slug: Some(resolved_slug),
          label: title,
          span: link.span,
        }),
      )
    }
    None => {
      self.add_dangling_tree_link(source_path, target)
      self.effects.diagnostics.push(
        @model.diagnostic(link.span, Binding, "dangling local link: " + target),
      )
      let label = link.text.unwrap_or(target)
      Ok(
        ResolvedLink({
          source: source_path,
          target,
          slug: None,
          label: LinkText(label),
          span: link.span,
        }),
      )
    }
  }
}

///|
fn ResolveState::resolve_link_fallback_label(
  self : ResolveState,
  tree : ResolvedTree,
  fallback : String,
) -> ResolvedLinkLabel {
  match tree.metadata.title {
    Some((content, _)) =>
      match
        self.resolve_rich_content(content, tree.slug.canonical(), tree.path) {
        Ok((contents, _)) => LinkResolvedContent(contents)
        Err(_) => LinkFallbackText(resolved_tree_title(tree))
      }
    None => LinkFallbackText(tree.metadata.page_title.unwrap_or(fallback))
  }
}

///|
fn resolved_tree_title(tree : ResolvedTree) -> String {
  let compiled : @model.CompiledTree = {
    slug: tree.slug,
    path: tree.path,
    html: "",
    metadata: tree.metadata,
    references: [],
    backlinks: [],
    parent: None,
  }
  @model.tree_title(compiled)
}

///|
fn ResolveState::resolve_embed_directive(
  self : ResolveState,
  embed : @model.EmbedDirective,
  parent_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  let target = embed.target
  match validate_tree_target(target, embed.span, "embed") {
    Some(error) => return Err(error)
    None => ()
  }
  let resolved_slug = @model.tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      match self.find_parsed(parent_slug) {
        Some(source_tree) =>
          self.add_dependency(
            source_tree.path,
            target_tree.path,
            @model.TreeEmbed,
          )
        None => ()
      }
      match self.compile_resolved_tree(resolved_key) {
        Ok(tree) => {
          if embed_is_open(embed) {
            add_all_strings(references, tree.references)
          }
          self.insert_parent(resolved_key, @model.TreeSlug::parse(parent_slug))
          Ok(ResolvedEmbed(embed, source_path, tree))
        }
        Err(error) => Err(error)
      }
    }
    None =>
      Err(
        @model.diagnostic(
          embed.span,
          Binding,
          "missing embed target: " + target,
        ),
      )
  }
}

///|
fn ResolveState::add_dependency(
  self : ResolveState,
  source : String,
  target : String,
  kind : @model.SourceFileDependencyKind,
) -> Unit {
  let dependency : @model.SourceFileDependency = { source, target, kind }
  if !self.effects.source_file_dependencies.contains(dependency) {
    self.effects.source_file_dependencies.push(dependency)
  }
}

///|
fn RenderState::render_embed_html(
  self : RenderState,
  embed : @model.EmbedDirective,
  tree : ResolvedTree,
  counter : RenderCounter,
) -> Result[String, @core.Diagnostic] {
  let resolved_key = tree.slug.canonical()
  let attrs = embed_attrs(embed, resolved_key)
  let body_html = match self.render_resolved_tree_body(tree) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let number = if embed.option.numbering { Some(counter.next()) } else { None }
  let catalog = if embed.option.catalog {
    self.render_embed_catalog(tree)
  } else {
    None
  }
  let nodes = match embed.title {
    Some(title) => {
      if embed.option.details_open {
        attrs.push(("open", None))
      }
      let summary_children = embed_summary_children(title, number)
      let children : Array[@sexp.SexpNode] = [
        @sexp.SexpNode::Element("summary", [], summary_children),
        @sexp.SexpNode::RawHtml(body_html),
      ]
      match catalog {
        Some(node) => children.push(node)
        None => ()
      }
      [@sexp.SexpNode::Element("details", attrs, children)]
    }
    None => {
      let children : Array[@sexp.SexpNode] = []
      match number {
        Some(number) =>
          children.push(
            @sexp.SexpNode::Element("div", [("class", Some("embed-number"))], [
              @sexp.SexpNode::Text(number.to_string() + "."),
            ]),
          )
        None => ()
      }
      children.push(@sexp.SexpNode::RawHtml(body_html))
      match catalog {
        Some(node) => children.push(node)
        None => ()
      }
      [@sexp.SexpNode::Element("div", attrs, children)]
    }
  }
  Ok(@sexp.render_html(nodes))
}

///|
fn RenderState::render_resolved_tree_body(
  self : RenderState,
  tree : ResolvedTree,
) -> Result[String, @core.Diagnostic] {
  self.render_resolved_content_nodes(
    tree.content.nodes,
    RenderCounter::new(),
    wrap_inline_content=tree.content.wrap_inline_content,
  )
}

///|
fn RenderState::render_resolved_content_nodes(
  self : RenderState,
  contents : Array[ResolvedContent],
  counter : RenderCounter,
  wrap_inline_content~ : Bool,
) -> Result[String, @core.Diagnostic] {
  let placeholders : Array[RenderPlaceholder] = []
  let nodes = resolved_contents_to_core_nodes(contents, placeholders)
  let next_placeholder = [0]
  let resolver : @html.ElementResolver = (call, _context) => {
    if call.tag != placeholder_tag() {
      return Ok(None)
    }
    let index = next_placeholder[0]
    next_placeholder[0] = index + 1
    guard placeholders.get(index) is Some(placeholder) else {
      return Err(
        @model.diagnostic(call.span, Binding, "missing render placeholder"),
      )
    }
    match placeholder {
      RenderLink(link) =>
        self
        .render_link_node(link)
        .map(node => Some(@html.ElementOutput::body([node])))
      RenderEmbed(embed, _, tree) =>
        self
        .render_embed_html(embed, tree, counter)
        .map(html => {
          Some(@html.ElementOutput::body([@sexp.SexpNode::RawHtml(html)]))
        })
    }
  }
  let options = {
    ..@html.CompileOptions::fragment(),
    wrap_inline_content,
    extensions: [resolver],
  }
  @html.compile_fragment(
    { source: @core.SourceInfo::default(), nodes },
    options~,
  ).map(nodes => @sexp.render_html(nodes))
}

///|
priv enum RenderPlaceholder {
  RenderLink(ResolvedLink)
  RenderEmbed(@model.EmbedDirective, String, ResolvedTree)
}

///|
fn resolved_contents_to_core_nodes(
  contents : Array[ResolvedContent],
  placeholders : Array[RenderPlaceholder],
) -> Array[@core.Node] {
  let nodes : Array[@core.Node] = []
  for content in contents {
    nodes.push(resolved_content_to_core_node(content, placeholders))
  }
  nodes
}

///|
fn resolved_content_to_core_node(
  content : ResolvedContent,
  placeholders : Array[RenderPlaceholder],
) -> @core.Node {
  match content {
    ResolvedText(text, span) => Text(text, span)
    ResolvedElement(tag, attrs, children, span) =>
      Element(
        tag,
        attrs,
        resolved_contents_to_core_nodes(children, placeholders),
        span,
      )
    ResolvedLink(link) => {
      let index = placeholders.length()
      placeholders.push(RenderLink(link))
      placeholder_node(index, link.span)
    }
    ResolvedEmbed(embed, source, tree) => {
      let index = placeholders.length()
      placeholders.push(RenderEmbed(embed, source, tree))
      placeholder_node(index, embed.span)
    }
  }
}

///|
fn placeholder_node(index : Int, span : @core.SourceSpan) -> @core.Node {
  Element(placeholder_tag(), [placeholder_attr(index, span)], [], span)
}

///|
fn placeholder_attr(index : Int, span : @core.SourceSpan) -> @core.Attr {
  { name: "data-index", value: Some(Scalar(index.to_string(), span)), span }
}

///|
fn placeholder_tag() -> String {
  "altsia.placeholder"
}

///|
fn RenderState::render_link_node(
  self : RenderState,
  link : ResolvedLink,
) -> Result[@sexp.SexpNode, @core.Diagnostic] {
  let label = match self.render_link_label(link.label) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match link.slug {
    Some(slug) =>
      Ok(
        Element("a", [("href", Some(@model.url_for_tree(slug)))], [
          RawHtml(label),
        ]),
      )
    None =>
      Ok(
        Element(
          "a",
          [("href", Some("#")), ("data-missing-target", Some(link.target))],
          [RawHtml(label)],
        ),
      )
  }
}

///|
fn RenderState::render_link_label(
  self : RenderState,
  label : ResolvedLinkLabel,
) -> Result[String, @core.Diagnostic] {
  match label {
    LinkText(value) => Ok(@sexp.render_html([Text(value)]))
    LinkResolvedContent(contents) =>
      self.render_resolved_content_nodes(
        contents.nodes,
        RenderCounter::new(),
        wrap_inline_content=contents.wrap_inline_content,
      )
    LinkFallbackText(value) => Ok(@sexp.render_html([Text(value)]))
  }
}

///|
fn RenderState::render_structured_preview(
  self : RenderState,
  entry_path : String,
  options : @model.PreviewOptions,
) -> Result[@model.StructuredPreview, @core.Diagnostic] {
  let entry_tree_slug = @model.tree_slug_from_path(entry_path)
  let entry_key = entry_tree_slug.canonical()
  let resolved = match self.resolved_by_slug.get(entry_key) {
    Some(tree) => tree
    None =>
      return Err(
        @model.source_diagnostic(
          entry_path,
          Binding,
          "missing entry tree: " + entry_path,
        ),
      )
  }
  let compiled_tree_index = match self.compiled_tree_index() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let compiled = match compiled_tree_index.get(entry_key) {
    Some(tree) => tree
    None =>
      return Err(
        @model.source_diagnostic(
          entry_path,
          Binding,
          "missing entry tree: " + entry_path,
        ),
      )
  }
  let context = PreviewRenderContext::new(options)
  let body = match self.render_preview_tree_body(resolved, context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let html = body + self.render_tree_footer(compiled)
  Ok({
    html,
    entry: entry_path,
    entry_tree_slug,
    title: @model.tree_page_title(compiled),
    diagnostics: self.effects.diagnostics,
    source_file_dependencies: source_file_dependencies_for_entry(
      self.effects.source_file_dependencies,
      compiled.path,
    ),
    dangling_tree_links: dangling_tree_links_for_entry(
      self.effects.dangling_tree_links,
      self.effects.source_file_dependencies,
      compiled.path,
    ),
    tree_links: context.tree_links,
    embeds: context.embeds,
    assets: context.assets,
  })
}

///|
fn PreviewRenderContext::new(
  options : @model.PreviewOptions,
) -> PreviewRenderContext {
  {
    options,
    tree_links: [],
    embeds: [],
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
fn RenderState::render_preview_tree_body(
  self : RenderState,
  tree : ResolvedTree,
  context : PreviewRenderContext,
) -> Result[String, @core.Diagnostic] {
  self.render_preview_content_nodes(
    tree.content.nodes,
    RenderCounter::new(),
    context,
    wrap_inline_content=tree.content.wrap_inline_content,
  )
}

///|
fn RenderState::render_preview_content_nodes(
  self : RenderState,
  contents : Array[ResolvedContent],
  counter : RenderCounter,
  context : PreviewRenderContext,
  wrap_inline_content~ : Bool,
) -> Result[String, @core.Diagnostic] {
  let placeholders : Array[RenderPlaceholder] = []
  let nodes = resolved_contents_to_core_nodes(contents, placeholders)
  let next_placeholder = [0]
  let resolver : @html.ElementResolver = (call, _compile_context) => {
    if call.tag != placeholder_tag() {
      return Ok(None)
    }
    let index = next_placeholder[0]
    next_placeholder[0] = index + 1
    guard placeholders.get(index) is Some(placeholder) else {
      return Err(
        @model.diagnostic(call.span, Binding, "missing render placeholder"),
      )
    }
    match placeholder {
      RenderLink(link) =>
        self
        .render_preview_link_node(link, context)
        .map(node => Some(@html.ElementOutput::body([node])))
      RenderEmbed(embed, source, tree) =>
        self
        .render_preview_embed_html(embed, source, tree, counter, context)
        .map(html => {
          Some(@html.ElementOutput::body([@sexp.SexpNode::RawHtml(html)]))
        })
    }
  }
  let options = {
    ..@html.CompileOptions::fragment(),
    wrap_inline_content,
    extensions: [resolver],
  }
  @html.compile_fragment(
    { source: @core.SourceInfo::default(), nodes },
    options~,
  ).map(nodes => @sexp.render_html(nodes))
}

///|
fn RenderState::render_preview_link_node(
  self : RenderState,
  link : ResolvedLink,
  context : PreviewRenderContext,
) -> Result[@sexp.SexpNode, @core.Diagnostic] {
  let label = match self.render_link_label(link.label) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let id = context.next_link_id()
  match link.slug {
    Some(slug) => {
      let href = @model.url_for_tree(slug)
      let target_source = self.source_path_for_slug(slug)
      context.tree_links.push({
        id,
        source: link.source,
        target: link.target,
        target_source,
        target_slug: Some(slug),
        href,
        missing: false,
      })
      let attrs : Array[(String, String?)] = [("href", Some(href))]
      if context.options.annotate_html {
        attrs.push(("data-altsia-link-id", Some(id)))
        attrs.push(("data-altsia-tree", Some(slug.canonical())))
        match target_source {
          Some(path) => attrs.push(("data-altsia-target-source", Some(path)))
          None => ()
        }
      }
      Ok(@sexp.SexpNode::Element("a", attrs, [@sexp.SexpNode::RawHtml(label)]))
    }
    None => {
      let href = "#"
      context.tree_links.push({
        id,
        source: link.source,
        target: link.target,
        target_source: None,
        target_slug: None,
        href,
        missing: true,
      })
      let attrs : Array[(String, String?)] = [
        ("href", Some(href)),
        ("data-missing-target", Some(link.target)),
      ]
      if context.options.annotate_html {
        attrs.push(("data-altsia-link-id", Some(id)))
      }
      Ok(@sexp.SexpNode::Element("a", attrs, [@sexp.SexpNode::RawHtml(label)]))
    }
  }
}

///|
fn RenderState::render_preview_embed_html(
  self : RenderState,
  embed : @model.EmbedDirective,
  source : String,
  tree : ResolvedTree,
  counter : RenderCounter,
  context : PreviewRenderContext,
) -> Result[String, @core.Diagnostic] {
  let resolved_key = tree.slug.canonical()
  let id = context.next_embed_id()
  context.embeds.push({
    id,
    source,
    target: embed.target,
    target_source: tree.path,
    target_slug: tree.slug,
    open: embed_is_open(embed),
  })
  let attrs = embed_attrs(embed, resolved_key)
  if context.options.annotate_html {
    attrs.push(("data-altsia-embed-id", Some(id)))
    attrs.push(("data-altsia-target-source", Some(tree.path)))
  }
  let body_html = match self.render_preview_tree_body(tree, context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let number = if embed.option.numbering { Some(counter.next()) } else { None }
  let catalog = if embed.option.catalog {
    self.render_embed_catalog(tree)
  } else {
    None
  }
  let nodes = match embed.title {
    Some(title) => {
      if embed.option.details_open {
        attrs.push(("open", None))
      }
      let summary_children = embed_summary_children(title, number)
      let children : Array[@sexp.SexpNode] = [
        @sexp.SexpNode::Element("summary", [], summary_children),
        @sexp.SexpNode::RawHtml(body_html),
      ]
      match catalog {
        Some(node) => children.push(node)
        None => ()
      }
      [@sexp.SexpNode::Element("details", attrs, children)]
    }
    None => {
      let children : Array[@sexp.SexpNode] = []
      match number {
        Some(number) =>
          children.push(
            @sexp.SexpNode::Element("div", [("class", Some("embed-number"))], [
              @sexp.SexpNode::Text(number.to_string() + "."),
            ]),
          )
        None => ()
      }
      children.push(@sexp.SexpNode::RawHtml(body_html))
      match catalog {
        Some(node) => children.push(node)
        None => ()
      }
      [@sexp.SexpNode::Element("div", attrs, children)]
    }
  }
  Ok(@sexp.render_html(nodes))
}

///|
fn RenderState::source_path_for_slug(
  self : RenderState,
  slug : @model.TreeSlug,
) -> String? {
  self.input.source_trees_by_slug.get(slug.canonical()).map(tree => tree.path)
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

///|
fn embed_summary_children(
  title : String,
  number : Int?,
) -> Array[@sexp.SexpNode] {
  match number {
    Some(number) =>
      [
        @sexp.SexpNode::Element("span", [("class", Some("embed-number"))], [
          @sexp.SexpNode::Text(number.to_string() + "."),
        ]),
        @sexp.SexpNode::Text(" " + title),
      ]
    None => [@sexp.SexpNode::Text(title)]
  }
}

///|
fn RenderState::render_embed_catalog(
  self : RenderState,
  tree : ResolvedTree,
) -> @sexp.SexpNode? {
  let visited : Set[String] = Set([tree.slug.canonical()])
  let items = self.render_embed_catalog_items(tree, visited)
  if items.is_empty() {
    None
  } else {
    Some(
      @sexp.SexpNode::Element(
        "nav",
        [
          ("class", Some("embed-catalog")),
          ("aria-label", Some("Embedded content")),
        ],
        [@sexp.SexpNode::Element("ol", [], items)],
      ),
    )
  }
}

///|
fn RenderState::render_embed_catalog_items(
  self : RenderState,
  tree : ResolvedTree,
  visited : Set[String],
) -> Array[@sexp.SexpNode] {
  let items : Array[@sexp.SexpNode] = []
  self.push_embed_catalog_items(items, tree.content.nodes, visited)
  items
}

///|
fn RenderState::push_embed_catalog_items(
  self : RenderState,
  items : Array[@sexp.SexpNode],
  contents : Array[ResolvedContent],
  visited : Set[String],
) -> Unit {
  for content in contents {
    match content {
      ResolvedElement(_, _, children, _) =>
        self.push_embed_catalog_items(items, children, visited)
      ResolvedEmbed(_, _, child) => {
        let child_key = child.slug.canonical()
        if !visited.contains(child_key) {
          visited.add(child_key)
          let children = self.render_embed_catalog_items(child, visited)
          let content : Array[@sexp.SexpNode] = [
            @sexp.SexpNode::Element(
              "a",
              [("href", Some(@model.url_for_tree(child.slug)))],
              [@sexp.SexpNode::Text(self.tree_footer_label(child_key))],
            ),
          ]
          if !children.is_empty() {
            content.push(@sexp.SexpNode::Element("ol", [], children))
          }
          items.push(@sexp.SexpNode::Element("li", [], content))
        }
      }
      _ => ()
    }
  }
}

///|
fn embed_is_open(embed : @model.EmbedDirective) -> Bool {
  match embed.title {
    Some(_) => embed.option.details_open
    None => true
  }
}

///|
fn validate_tree_target(
  target : String,
  span : @core.SourceSpan,
  tag : String,
) -> @core.Diagnostic? {
  let trimmed = target.trim()
  if trimmed == "" {
    Some(
      @model.diagnostic(span, Binding, "(" + tag + " ...) requires a target"),
    )
  } else if trimmed != target {
    Some(
      @model.diagnostic(
        span,
        Binding,
        "(" +
        tag +
        " ...) target must not contain leading or trailing whitespace",
        hint="target was: " + target,
      ),
    )
  } else if target.contains("://") ||
    target.contains("#") ||
    target.contains("?") {
    Some(
      @model.diagnostic(
        span,
        Binding,
        "(" + tag + " ...) target must be a local tree target",
        hint="target was: " + target,
      ),
    )
  } else if is_absolute_tree_target(target) || @model.has_suffix(target, ".alt") {
    None
  } else {
    Some(
      @model.diagnostic(
        span,
        Binding,
        "(" + tag + " ...) relative target must end with .alt",
        hint="target was: " + target,
      ),
    )
  }
}

///|
fn is_absolute_tree_target(target : String) -> Bool {
  target.length() > 0 && target.unsafe_substring(start=0, end=1) == "/"
}

///|
fn embed_attrs(
  embed : @model.EmbedDirective,
  resolved_key : String,
) -> Array[(String, String?)] {
  let attrs = [("class", Some("embed")), ("data-tree", Some(resolved_key))]
  if embed.option.numbering {
    attrs.push(("data-numbering", Some("true")))
  }
  if !embed.option.catalog {
    attrs.push(("data-catalog", Some("false")))
  }
  attrs
}

///|
fn ResolveState::add_dangling_tree_link(
  self : ResolveState,
  source : String,
  target : String,
) -> Unit {
  let link : @model.DanglingTreeLink = { source, target }
  if !self.effects.dangling_tree_links.contains(link) {
    self.effects.dangling_tree_links.push(link)
  }
}

///|
fn ResolveState::specify_parent(
  self : ResolveState,
  slug : String,
  parent : @model.TreeSlug,
) -> Unit {
  let value = self.tree_relations(slug)
  self.effects.tree_relations_by_slug[slug] = {
    ..value,
    parent: Some(parent),
    explicit_parent: true,
  }
}

///|
fn ResolveState::insert_parent(
  self : ResolveState,
  slug : String,
  parent : @model.TreeSlug,
) -> Unit {
  let value = self.tree_relations(slug)
  if !value.explicit_parent {
    self.effects.tree_relations_by_slug[slug] = {
      ..value,
      parent: Some(parent),
    }
  }
}

///|
fn ResolveState::insert_backlink(
  self : ResolveState,
  slug : String,
  backlink : String,
) -> Unit {
  let value = self.tree_relations(slug)
  value.backlinks.add(backlink)
  self.effects.tree_relations_by_slug[slug] = value
}

///|
fn ResolveState::tree_relations(
  self : ResolveState,
  slug : String,
) -> TreeRelations {
  self.effects.tree_relations_by_slug
  .get(slug)
  .unwrap_or({ parent: None, explicit_parent: false, backlinks: Set([]) })
}

///|
fn add_all_strings(target : Set[String], source : Set[String]) -> Unit {
  for value in source {
    target.add(value)
  }
}

///|
fn RenderState::compiled_tree_index(
  self : RenderState,
) -> Result[Map[String, @model.CompiledTree], @core.Diagnostic] {
  let index : Map[String, @model.CompiledTree] = Map([])
  for slug in self.input.tree_order {
    match self.resolved_by_slug.get(slug) {
      Some(tree) =>
        match self.to_compiled_tree(tree) {
          Ok(compiled) => index[slug] = compiled
          Err(error) => return Err(error)
        }
      None => ()
    }
  }
  Ok(index)
}

///|
fn RenderState::to_compiled_tree(
  self : RenderState,
  tree : ResolvedTree,
) -> Result[@model.CompiledTree, @core.Diagnostic] {
  let references = string_set_to_slugs(
    self.resolved_tree_references(tree, Set([tree.slug.canonical()])),
  )
  let backlinks = string_set_to_slugs(
    self.resolved_tree_backlinks(tree, Set([tree.slug.canonical()])),
  )
  let parent = match
    self.effects.tree_relations_by_slug.get(tree.slug.canonical()) {
    Some(value) => value.parent
    None => None
  }
  let html = match self.render_resolved_tree_body(tree) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let compiled : @model.CompiledTree = {
    slug: tree.slug,
    path: tree.path,
    html,
    metadata: tree.metadata,
    references,
    backlinks,
    parent,
  }
  Ok({ ..compiled, html: html + self.render_tree_footer(compiled) })
}

///|
fn RenderState::resolved_tree_references(
  self : RenderState,
  tree : ResolvedTree,
  visited : Set[String],
) -> Set[String] {
  let references = tree.references.copy()
  self.add_embedded_references(references, tree.content.nodes, visited)
  references
}

///|
fn RenderState::add_embedded_references(
  self : RenderState,
  references : Set[String],
  contents : Array[ResolvedContent],
  visited : Set[String],
) -> Unit {
  for content in contents {
    match content {
      ResolvedElement(_, _, children, _) =>
        self.add_embedded_references(references, children, visited)
      ResolvedEmbed(embed, _, child) =>
        if embed_is_open(embed) {
          let child_key = child.slug.canonical()
          if !visited.contains(child_key) {
            visited.add(child_key)
            add_all_strings(
              references,
              self.resolved_tree_references(child, visited),
            )
          }
        }
      _ => ()
    }
  }
}

///|
fn RenderState::resolved_tree_backlinks(
  self : RenderState,
  tree : ResolvedTree,
  visited : Set[String],
) -> Set[String] {
  let backlinks = match
    self.effects.tree_relations_by_slug.get(tree.slug.canonical()) {
    Some(value) => value.backlinks.copy()
    None => Set([])
  }
  self.add_embedded_backlinks(backlinks, tree.content.nodes, visited)
  backlinks
}

///|
fn RenderState::add_embedded_backlinks(
  self : RenderState,
  backlinks : Set[String],
  contents : Array[ResolvedContent],
  visited : Set[String],
) -> Unit {
  for content in contents {
    match content {
      ResolvedElement(_, _, children, _) =>
        self.add_embedded_backlinks(backlinks, children, visited)
      ResolvedEmbed(embed, _, child) =>
        if embed_is_open(embed) {
          let child_key = child.slug.canonical()
          if !visited.contains(child_key) {
            visited.add(child_key)
            add_all_strings(
              backlinks,
              self.resolved_tree_backlinks(child, visited),
            )
          }
        }
      _ => ()
    }
  }
}

///|
fn string_set_to_slugs(values : Set[String]) -> Array[@model.TreeSlug] {
  let slugs : Array[@model.TreeSlug] = []
  for value in values {
    slugs.push(@model.TreeSlug::parse(value))
  }
  slugs
}

///|
fn RenderState::render_tree_footer(
  self : RenderState,
  tree : @model.CompiledTree,
) -> String {
  if tree.metadata.footer_mode == "none" {
    return ""
  }
  let sections : Array[@sexp.SexpNode] = []
  if tree.metadata.show_references {
    match self.footer_section("References", tree.references, tree.metadata) {
      Some(section) => sections.push(section)
      None => ()
    }
  }
  if tree.metadata.show_backlinks {
    match self.footer_section("Backlinks", tree.backlinks, tree.metadata) {
      Some(section) => sections.push(section)
      None => ()
    }
  }
  if sections.is_empty() {
    ""
  } else {
    @sexp.render_html([
      @sexp.SexpNode::Element(
        "footer",
        [("class", Some("tree-footer"))],
        sections,
      ),
    ])
  }
}

///|
fn RenderState::footer_section(
  self : RenderState,
  title : String,
  slugs : Array[@model.TreeSlug],
  metadata : @model.Metadata,
) -> @sexp.SexpNode? {
  let ordered = self.ordered_footer_slugs(slugs, metadata.footer_sort_by)
  if ordered.is_empty() {
    None
  } else {
    let items : Array[@sexp.SexpNode] = []
    for slug in ordered {
      items.push(
        @sexp.SexpNode::Element("li", [], [
          self.footer_item_node(slug, metadata.footer_mode),
        ]),
      )
    }
    Some(
      @sexp.SexpNode::Element(
        "section",
        [("class", Some(footer_class(title)))],
        [
          @sexp.SexpNode::Element("h2", [], [@sexp.SexpNode::Text(title)]),
          @sexp.SexpNode::Element("ol", [], items),
        ],
      ),
    )
  }
}

///|
fn footer_class(title : String) -> String {
  match title {
    "References" => "tree-references"
    "Backlinks" => "tree-backlinks"
    _ => "tree-links"
  }
}

///|
fn RenderState::ordered_footer_slugs(
  self : RenderState,
  slugs : Array[@model.TreeSlug],
  sort_by : String?,
) -> Array[@model.TreeSlug] {
  let ordered = unique_slugs(slugs)
  match sort_by {
    Some("slug") =>
      ordered.sort_by((a, b) => {
        lexicographic_compare(a.canonical(), b.canonical())
      })
    Some("title") =>
      ordered.sort_by((a, b) => {
        lexicographic_compare(
          self.tree_footer_label(a.canonical()),
          self.tree_footer_label(b.canonical()),
        )
      })
    _ => ()
  }
  ordered
}

///|
fn lexicographic_compare(left : String, right : String) -> Int {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let length = left_chars.length().min(right_chars.length())
  for i in 0..<length {
    let compared = left_chars[i].compare(right_chars[i])
    if compared != 0 {
      return compared
    }
  }
  left_chars.length() - right_chars.length()
}

///|
fn unique_slugs(slugs : Array[@model.TreeSlug]) -> Array[@model.TreeSlug] {
  let result : Array[@model.TreeSlug] = []
  for slug in slugs {
    if !result.contains(slug) {
      result.push(slug)
    }
  }
  result
}

///|
fn RenderState::footer_item_node(
  self : RenderState,
  slug : @model.TreeSlug,
  mode : String,
) -> @sexp.SexpNode {
  let label = self.tree_footer_label(slug.canonical())
  match mode {
    "text" => @sexp.SexpNode::Text(label)
    _ =>
      @sexp.SexpNode::Element(
        "a",
        [("href", Some(@model.url_for_tree(slug)))],
        [@sexp.SexpNode::Text(label)],
      )
  }
}

///|
fn RenderState::tree_footer_label(self : RenderState, slug : String) -> String {
  match self.resolved_by_slug.get(slug) {
    Some(tree) => resolved_tree_title(tree)
    None => slug
  }
}

///|
fn RenderState::ordered_compiled_trees(
  self : RenderState,
  compiled_tree_index : Map[String, @model.CompiledTree],
) -> Array[@model.CompiledTree] {
  let ordered : Array[@model.CompiledTree] = []
  for slug in self.input.tree_order {
    match compiled_tree_index.get(slug) {
      Some(tree) => ordered.push(tree)
      None => ()
    }
  }
  ordered
}

///|
fn source_file_dependency_key(
  source : String,
  target : String,
  kind : @model.SourceFileDependencyKind,
) -> String {
  source + "\u{1f}" + target + "\u{1f}" + source_file_dependency_kind_key(kind)
}

///|
fn source_file_dependency_kind_key(
  kind : @model.SourceFileDependencyKind,
) -> String {
  match kind {
    @model.LibraryUse => "library-use"
    @model.TreeLink => "tree-link"
    @model.TreeEmbed => "tree-embed"
  }
}

///|
pub fn expand_dirty_sources(
  project : @model.CompiledProject,
  dirty_sources : Array[String],
) -> Array[String] {
  let graph = dirty_source_file_graph(project.source_file_dependencies)
  let result : Array[String] = []
  let visited : Set[String] = Set([])
  let queue : Array[String] = []
  for source in dirty_sources {
    let normalized = @model.normalize_path(source)
    if !visited.contains(normalized) {
      visited.add(normalized)
      queue.push(normalized)
      result.push(normalized)
    }
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let source = queue[cursor]
    cursor += 1
    match graph.get(source) {
      Some(next_sources) =>
        for next in next_sources {
          if !visited.contains(next) {
            visited.add(next)
            queue.push(next)
            result.push(next)
          }
        }
      None => ()
    }
  }
  result
}

///|
fn dirty_source_file_graph(
  source_file_dependencies : Array[@model.SourceFileDependency],
) -> Map[String, Array[String]] {
  let graph : Map[String, Array[String]] = Map([])
  for dependency in source_file_dependencies {
    match dependency.kind {
      @model.LibraryUse =>
        push_string_map_array(graph, dependency.target, dependency.source)
      @model.TreeLink => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
      @model.TreeEmbed => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
    }
  }
  graph
}

///|
pub fn source_file_dependencies_for_entry(
  source_file_dependencies : Array[@model.SourceFileDependency],
  entry_path : String,
) -> Array[@model.SourceFileDependency] {
  let by_source : Map[String, Array[@model.SourceFileDependency]] = Map([])
  for dependency in source_file_dependencies {
    push_source_file_dependency_map_array(
      by_source,
      dependency.source,
      dependency,
    )
  }
  let result : Array[@model.SourceFileDependency] = []
  let emitted : Set[String] = Set([])
  let visited : Set[String] = Set([])
  let queue : Array[String] = [entry_path]
  let mut cursor = 0
  visited.add(entry_path)
  while cursor < queue.length() {
    let source = queue[cursor]
    cursor += 1
    match by_source.get(source) {
      Some(edges) =>
        for dependency in edges {
          let key = source_file_dependency_key(
            dependency.source,
            dependency.target,
            dependency.kind,
          )
          if !emitted.contains(key) {
            emitted.add(key)
            result.push(dependency)
          }
          if !visited.contains(dependency.target) {
            visited.add(dependency.target)
            queue.push(dependency.target)
          }
        }
      None => ()
    }
  }
  result
}

///|
pub fn dangling_tree_links_for_entry(
  dangling_tree_links : Array[@model.DanglingTreeLink],
  source_file_dependencies : Array[@model.SourceFileDependency],
  entry_path : String,
) -> Array[@model.DanglingTreeLink] {
  let reachable : Set[String] = Set([entry_path])
  let deps = source_file_dependencies_for_entry(
    source_file_dependencies, entry_path,
  )
  for dep in deps {
    reachable.add(dep.source)
    reachable.add(dep.target)
  }
  dangling_tree_links.filter(link => reachable.contains(link.source))
}

///|
fn push_source_file_dependency_map_array(
  table : Map[String, Array[@model.SourceFileDependency]],
  key : String,
  value : @model.SourceFileDependency,
) -> Unit {
  match table.get(key) {
    Some(values) => {
      values.push(value)
      table[key] = values
    }
    None => table[key] = [value]
  }
}

///|
fn push_string_map_array(
  table : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  match table.get(key) {
    Some(values) =>
      if !values.contains(value) {
        values.push(value)
        table[key] = values
      }
    None => table[key] = [value]
  }
}
