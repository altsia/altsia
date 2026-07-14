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
) -> ResolvedTree raise @core.Diagnostic {
  if self.find_resolved(slug) is Some(tree) {
    return tree
  }
  if self.visiting.contains(slug) {
    raise self.cycle_diagnostic(slug)
  }
  let tree = match self.find_parsed(slug) {
    Some(value) => value
    None =>
      raise @model.source_diagnostic(slug, Binding, "missing tree: " + slug)
  }
  self.visiting.add(slug)
  self.active_stack.push(slug)
  let resolved = try self.resolve_tree_content(tree) catch {
    error => {
      ignore(self.active_stack.pop())
      self.visiting.remove(slug)
      raise error
    }
  } noraise {
    value => {
      ignore(self.active_stack.pop())
      self.visiting.remove(slug)
      value
    }
  }
  let (contents, references) = resolved
  let compiled : ResolvedTree = {
    slug: tree.slug,
    path: tree.path,
    metadata: tree.metadata,
    content: contents,
    references,
  }
  if tree.metadata.parent is Some(parent) {
    self.specify_parent(slug, parent)
  }
  self.resolved_by_slug[slug] = compiled
  compiled
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
) -> (ResolvedRichContent, Set[String]) raise @core.Diagnostic {
  self.resolve_rich_content(tree.content, tree.slug.canonical(), tree.path)
}

///|
fn ResolveState::resolve_rich_content(
  self : ResolveState,
  content : @model.RichContent,
  source_slug : String,
  source_path : String,
) -> (ResolvedRichContent, Set[String]) raise @core.Diagnostic {
  let nodes : Array[ResolvedContent] = []
  let references : Set[String] = Set([])
  for node in content.nodes {
    nodes.push(
      self.resolve_rich_content_node(node, source_slug, source_path, references),
    )
  }
  ({ nodes, wrap_inline_content: content.wrap_inline_content }, references)
}

///|
fn ResolveState::resolve_rich_content_node(
  self : ResolveState,
  node : @model.RichContentNode,
  source_slug : String,
  source_path : String,
  references : Set[String],
) -> ResolvedContent raise @core.Diagnostic {
  match node {
    @model.RichText(text, span) => ResolvedText(text, span)
    @model.RichElement(tag, attrs, children, span) => {
      let resolved_children : Array[ResolvedContent] = []
      for child in children {
        resolved_children.push(
          self.resolve_rich_content_node(
            child, source_slug, source_path, references,
          ),
        )
      }
      ResolvedElement(tag, attrs, resolved_children, span)
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
) -> ResolvedContent raise @core.Diagnostic {
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
) -> ResolvedContent raise @core.Diagnostic {
  let target = link.target
  if validate_tree_target(target, link.span, "link") is Some(error) {
    raise error
  }
  let resolved_slug = @model.tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      self.add_dependency(source_path, target_tree.path, @model.TreeLink)
      if self.find_parsed(source_slug) is Some(source_tree) {
        if target_tree.metadata.asref && source_slug != resolved_key {
          references.add(resolved_key)
        }
        if source_tree.metadata.asback && source_slug != resolved_key {
          self.insert_backlink(resolved_key, source_tree.slug.canonical())
        }
      }
      let title = match link.text {
        Some(value) => LinkText(value)
        None =>
          try self.compile_resolved_tree(resolved_key) catch {
            _ => LinkFallbackText(resolved_key)
          } noraise {
            tree => self.resolve_link_fallback_label(tree, resolved_key)
          }
      }
      ResolvedLink({
        source: source_path,
        target,
        slug: Some(resolved_slug),
        label: title,
        span: link.span,
      })
    }
    None => {
      self.add_dangling_tree_link(source_path, target)
      self.effects.diagnostics.push(
        @model.diagnostic(link.span, Binding, "dangling local link: " + target),
      )
      let label = link.text.unwrap_or(target)
      ResolvedLink({
        source: source_path,
        target,
        slug: None,
        label: LinkText(label),
        span: link.span,
      })
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
      try
        self.resolve_rich_content(content, tree.slug.canonical(), tree.path)
      catch {
        _ => LinkFallbackText(resolved_tree_title(tree))
      } noraise {
        result => LinkResolvedContent(result.0)
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
) -> ResolvedContent raise @core.Diagnostic {
  let target = embed.target
  if validate_tree_target(target, embed.span, "embed") is Some(error) {
    raise error
  }
  let resolved_slug = @model.tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_parsed(resolved_key) {
    Some(target_tree) => {
      if self.find_parsed(parent_slug) is Some(source_tree) {
        self.add_dependency(
          source_tree.path,
          target_tree.path,
          @model.TreeEmbed,
        )
      }
      let tree = self.compile_resolved_tree(resolved_key)
      if embed_is_open(embed) {
        add_all_strings(references, tree.references)
      }
      self.insert_parent(resolved_key, @model.TreeSlug::parse(parent_slug))
      ResolvedEmbed(embed, source_path, tree)
    }
    None =>
      raise @model.diagnostic(
        embed.span,
        Binding,
        "missing embed target: " + target,
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
