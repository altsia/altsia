///|
priv struct CompileInput {
  root : String
  tree_order : Array[String]
  source_trees_by_slug : Map[String, ParsedTree]
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
  source_file_dependencies : Array[SourceFileDependency]
  dangling_tree_links : Array[DanglingTreeLink]
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
  ResolvedHtml(String)
  ResolvedLink(ResolvedLink)
  ResolvedEmbed(EmbedDirective, ResolvedTree)
}

///|
priv enum ResolvedLinkLabel {
  LinkText(String)
  LinkResolvedContent(Array[ResolvedContent])
  LinkFallbackText(String)
}

///|
priv struct ResolvedLink {
  target : String
  slug : TreeSlug?
  label : ResolvedLinkLabel
}

///|
priv struct ResolvedTree {
  slug : TreeSlug
  path : String
  metadata : Metadata
  contents : Array[ResolvedContent]
  references : Set[String]
}

///|
priv struct TreeRelations {
  parent : TreeSlug?
  explicit_parent : Bool
  backlinks : Set[String]
}

///|
priv struct RenderCounter {
  values : Array[Int]
}

///|
fn CompileInput::new(root : String, parsed : Array[ParsedTree]) -> CompileInput {
  let tree_order : Array[String] = []
  let source_trees_by_slug : Map[String, ParsedTree] = Map([])
  for tree in parsed {
    let key = tree.slug.canonical()
    tree_order.push(key)
    source_trees_by_slug[key] = tree
  }
  { root, tree_order, source_trees_by_slug }
}

///|
fn CompileEffects::new(parsed : Array[ParsedTree]) -> CompileEffects {
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
  parsed : Array[ParsedTree],
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
  parsed : Array[ParsedTree],
) -> Result[CompiledProject, @core.Diagnostic] {
  let input = CompileInput::new(root, parsed)
  ResolveState::new(input, parsed).compile_all()
}

///|
fn ResolveState::compile_all(
  self : ResolveState,
) -> Result[CompiledProject, @core.Diagnostic] {
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
) -> Result[CompiledProject, @core.Diagnostic] {
  let compiled_tree_index = self.compiled_tree_index()
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
  parsed : Array[ParsedTree],
) -> Array[SourceFileDependency] {
  let source_file_dependencies : Array[SourceFileDependency] = []
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
fn ResolveState::find_parsed(self : ResolveState, slug : String) -> ParsedTree? {
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
      return Err(source_diagnostic(slug, Binding, "missing tree: " + slug))
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
    contents,
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
  source_diagnostic(slug, Binding, "cyclic embed", hint=chain)
}

///|
fn ResolveState::resolve_tree_content(
  self : ResolveState,
  tree : ParsedTree,
) -> Result[(Array[ResolvedContent], Set[String]), @core.Diagnostic] {
  self.resolve_rich_content(tree.content, tree.slug.canonical(), tree.path)
}

///|
fn ResolveState::resolve_rich_content(
  self : ResolveState,
  content : RichContent,
  source_slug : String,
  source_path : String,
) -> Result[(Array[ResolvedContent], Set[String]), @core.Diagnostic] {
  let chunks : Array[ResolvedContent] = []
  let references : Set[String] = Set([])
  for chunk in content {
    match chunk {
      HtmlChunk(html) => chunks.push(ResolvedHtml(html))
      DirectiveChunk(directive) =>
        match
          self.resolve_rich_content_directive(
            directive, source_slug, source_path, references,
          ) {
          Ok(content) => chunks.push(content)
          Err(error) => return Err(error)
        }
    }
  }
  Ok((chunks, references))
}

///|
fn ResolveState::resolve_rich_content_directive(
  self : ResolveState,
  directive : RichContentDirective,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  match directive {
    RichLinkDirective(link) =>
      self.resolve_link_directive(link, source_slug, source_path, references)
    RichEmbedDirective(embed) =>
      self.resolve_embed_directive(embed, source_slug, source_path, references)
  }
}

///|
fn ResolveState::resolve_link_directive(
  self : ResolveState,
  link : LinkDirective,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  let target = link.target
  match validate_tree_target(target, link.span, "link") {
    Some(error) => return Err(error)
    None => ()
  }
  let resolved_slug = tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      self.add_dependency(source_path, target_tree.path, TreeLink)
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
      Ok(ResolvedLink({ target, slug: Some(resolved_slug), label: title }))
    }
    None => {
      self.add_dangling_tree_link(source_path, target)
      self.effects.diagnostics.push(
        diagnostic(link.span, Binding, "dangling local link: " + target),
      )
      let label = link.text.unwrap_or(target)
      Ok(ResolvedLink({ target, slug: None, label: LinkText(label) }))
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
  let compiled : CompiledTree = {
    slug: tree.slug,
    path: tree.path,
    html: "",
    metadata: tree.metadata,
    references: [],
    backlinks: [],
    parent: None,
  }
  tree_title(compiled)
}

///|
fn ResolveState::resolve_embed_directive(
  self : ResolveState,
  embed : EmbedDirective,
  parent_slug : String,
  source_path : String,
  references : Set[String],
) -> Result[ResolvedContent, @core.Diagnostic] {
  let target = embed.target
  match validate_tree_target(target, embed.span, "embed") {
    Some(error) => return Err(error)
    None => ()
  }
  let resolved_slug = tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      match self.find_parsed(parent_slug) {
        Some(source_tree) =>
          self.add_dependency(source_tree.path, target_tree.path, TreeEmbed)
        None => ()
      }
      match self.compile_resolved_tree(resolved_key) {
        Ok(tree) => {
          if embed_is_open(embed) {
            add_all_strings(references, tree.references)
          }
          self.insert_parent(resolved_key, TreeSlug::parse(parent_slug))
          Ok(ResolvedEmbed(embed, tree))
        }
        Err(error) => Err(error)
      }
    }
    None =>
      Err(diagnostic(embed.span, Binding, "missing embed target: " + target))
  }
}

///|
fn ResolveState::add_dependency(
  self : ResolveState,
  source : String,
  target : String,
  kind : SourceFileDependencyKind,
) -> Unit {
  let dependency : SourceFileDependency = { source, target, kind }
  if !self.effects.source_file_dependencies.contains(dependency) {
    self.effects.source_file_dependencies.push(dependency)
  }
}

///|
fn RenderState::render_embed_html(
  self : RenderState,
  embed : EmbedDirective,
  tree : ResolvedTree,
  counter : RenderCounter,
) -> String {
  let resolved_key = tree.slug.canonical()
  let attrs = embed_attrs(embed, resolved_key)
  let body_html = self.render_resolved_tree_body(tree)
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
  @sexp.render_html(nodes)
}

///|
fn RenderState::render_resolved_tree_body(
  self : RenderState,
  tree : ResolvedTree,
) -> String {
  self.render_resolved_contents(tree.contents, RenderCounter::new())
}

///|
fn RenderState::render_resolved_contents(
  self : RenderState,
  contents : Array[ResolvedContent],
  counter : RenderCounter,
) -> String {
  let chunks : Array[String] = []
  for content in contents {
    match content {
      ResolvedHtml(html) => chunks.push(html)
      ResolvedLink(link) => chunks.push(self.render_link_html(link))
      ResolvedEmbed(embed, tree) =>
        chunks.push(self.render_embed_html(embed, tree, counter))
    }
  }
  chunks.join("")
}

///|
fn RenderState::render_link_html(
  self : RenderState,
  link : ResolvedLink,
) -> String {
  let label = self.render_link_label(link.label)
  match link.slug {
    Some(slug) =>
      @sexp.render_html([
        Element("a", [("href", Some(url_for_tree(slug)))], [RawHtml(label)]),
      ])
    None =>
      @sexp.render_html([
        Element(
          "a",
          [("href", Some("#")), ("data-missing-target", Some(link.target))],
          [RawHtml(label)],
        ),
      ])
  }
}

///|
fn RenderState::render_link_label(
  self : RenderState,
  label : ResolvedLinkLabel,
) -> String {
  match label {
    LinkText(value) => @sexp.render_html([Text(value)])
    LinkResolvedContent(contents) =>
      self.render_resolved_contents(contents, RenderCounter::new())
    LinkFallbackText(value) => @sexp.render_html([Text(value)])
  }
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
  for content in tree.contents {
    match content {
      ResolvedEmbed(_, child) => {
        let child_key = child.slug.canonical()
        if !visited.contains(child_key) {
          visited.add(child_key)
          let children = self.render_embed_catalog_items(child, visited)
          let content : Array[@sexp.SexpNode] = [
            @sexp.SexpNode::Element(
              "a",
              [("href", Some(url_for_tree(child.slug)))],
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
  items
}

///|
fn embed_is_open(embed : EmbedDirective) -> Bool {
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
    Some(diagnostic(span, Binding, "(" + tag + " ...) requires a target"))
  } else if trimmed != target {
    Some(
      diagnostic(
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
      diagnostic(
        span,
        Binding,
        "(" + tag + " ...) target must be a local tree target",
        hint="target was: " + target,
      ),
    )
  } else if is_absolute_tree_target(target) || has_suffix(target, ".alt") {
    None
  } else {
    Some(
      diagnostic(
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
  embed : EmbedDirective,
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
  let link : DanglingTreeLink = { source, target }
  if !self.effects.dangling_tree_links.contains(link) {
    self.effects.dangling_tree_links.push(link)
  }
}

///|
fn ResolveState::specify_parent(
  self : ResolveState,
  slug : String,
  parent : TreeSlug,
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
  parent : TreeSlug,
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
) -> Map[String, CompiledTree] {
  let index : Map[String, CompiledTree] = Map([])
  for slug in self.input.tree_order {
    match self.resolved_by_slug.get(slug) {
      Some(tree) => index[slug] = self.to_compiled_tree(tree)
      None => ()
    }
  }
  index
}

///|
fn RenderState::to_compiled_tree(
  self : RenderState,
  tree : ResolvedTree,
) -> CompiledTree {
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
  let html = self.render_resolved_tree_body(tree)
  let compiled : @model.CompiledTree = {
    slug: tree.slug,
    path: tree.path,
    html,
    metadata: tree.metadata,
    references,
    backlinks,
    parent,
  }
  { ..compiled, html: html + self.render_tree_footer(compiled) }
}

///|
fn RenderState::resolved_tree_references(
  self : RenderState,
  tree : ResolvedTree,
  visited : Set[String],
) -> Set[String] {
  let references = tree.references.copy()
  for content in tree.contents {
    match content {
      ResolvedEmbed(embed, child) =>
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
  references
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
  for content in tree.contents {
    match content {
      ResolvedEmbed(embed, child) =>
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
  backlinks
}

///|
fn string_set_to_slugs(values : Set[String]) -> Array[TreeSlug] {
  let slugs : Array[TreeSlug] = []
  for value in values {
    slugs.push(TreeSlug::parse(value))
  }
  slugs
}

///|
fn RenderState::render_tree_footer(
  self : RenderState,
  tree : CompiledTree,
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
  slugs : Array[TreeSlug],
  metadata : Metadata,
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
  slugs : Array[TreeSlug],
  sort_by : String?,
) -> Array[TreeSlug] {
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
fn unique_slugs(slugs : Array[TreeSlug]) -> Array[TreeSlug] {
  let result : Array[TreeSlug] = []
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
  slug : TreeSlug,
  mode : String,
) -> @sexp.SexpNode {
  let label = self.tree_footer_label(slug.canonical())
  match mode {
    "text" => @sexp.SexpNode::Text(label)
    _ =>
      @sexp.SexpNode::Element("a", [("href", Some(url_for_tree(slug)))], [
        @sexp.SexpNode::Text(label),
      ])
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
  compiled_tree_index : Map[String, CompiledTree],
) -> Array[CompiledTree] {
  let ordered : Array[CompiledTree] = []
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
  kind : SourceFileDependencyKind,
) -> String {
  source + "\u{1f}" + target + "\u{1f}" + source_file_dependency_kind_key(kind)
}

///|
fn source_file_dependency_kind_key(kind : SourceFileDependencyKind) -> String {
  match kind {
    LibraryUse => "library-use"
    TreeLink => "tree-link"
    TreeEmbed => "tree-embed"
  }
}

///|
pub fn expand_dirty_sources(
  project : CompiledProject,
  dirty_sources : Array[String],
) -> Array[String] {
  let graph = dirty_source_file_graph(project.source_file_dependencies)
  let result : Array[String] = []
  let visited : Set[String] = Set([])
  let queue : Array[String] = []
  for source in dirty_sources {
    let normalized = normalize_path(source)
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
  source_file_dependencies : Array[SourceFileDependency],
) -> Map[String, Array[String]] {
  let graph : Map[String, Array[String]] = Map([])
  for dependency in source_file_dependencies {
    match dependency.kind {
      LibraryUse =>
        push_string_map_array(graph, dependency.target, dependency.source)
      TreeLink => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
      TreeEmbed => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
    }
  }
  graph
}

///|
pub fn source_file_dependencies_for_entry(
  source_file_dependencies : Array[SourceFileDependency],
  entry_path : String,
) -> Array[SourceFileDependency] {
  let by_source : Map[String, Array[SourceFileDependency]] = Map([])
  for dependency in source_file_dependencies {
    push_source_file_dependency_map_array(
      by_source,
      dependency.source,
      dependency,
    )
  }
  let result : Array[SourceFileDependency] = []
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
  dangling_tree_links : Array[DanglingTreeLink],
  source_file_dependencies : Array[SourceFileDependency],
  entry_path : String,
) -> Array[DanglingTreeLink] {
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
  table : Map[String, Array[SourceFileDependency]],
  key : String,
  value : SourceFileDependency,
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
