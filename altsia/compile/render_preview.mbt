///|
fn RenderState::render_structured_preview(
  self : RenderState,
  entry_path : String,
  options : @model.PreviewOptions,
) -> @model.StructuredPreview raise @core.Diagnostic {
  let entry_tree_slug = @model.TreeSlug::from_file_path(entry_path)
  let entry_key = entry_tree_slug.canonical()
  guard self.resolved_by_slug.get(entry_key) is Some(resolved) else {
    raise @model.source_diagnostic(
      entry_path,
      Binding,
      "missing entry tree: " + entry_path,
    )
  }
  let compiled_tree_index = self.compiled_tree_index()
  guard compiled_tree_index.get(entry_key) is Some(compiled) else {
    raise @model.source_diagnostic(
      entry_path,
      Binding,
      "missing entry tree: " + entry_path,
    )
  }
  let context = PreviewRenderContext::new(options)
  let body = self.render_preview_tree_body(resolved, context)
  let html = body + self.render_tree_footer(compiled)
  {
    html,
    entry: entry_path,
    entry_tree_slug,
    title: compiled.page_title(),
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
  }
}

///|
fn RenderState::render_preview_tree_body(
  self : RenderState,
  tree : ResolvedTree,
  context : PreviewRenderContext,
) -> String raise @core.Diagnostic {
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
) -> String raise @core.Diagnostic {
  let placeholders : Array[RenderPlaceholder] = []
  let nodes = resolved_contents_to_core_nodes(contents, placeholders)
  let next_placeholder = [0]
  let resolver : @html.ElementResolver = compiler => {
    if compiler.call.tag != placeholder_tag() {
      return None
    }
    let index = next_placeholder[0]
    next_placeholder[0] = index + 1
    guard placeholders.get(index) is Some(placeholder) else {
      raise @model.diagnostic(
        compiler.call.span,
        Binding,
        "missing render placeholder",
      )
    }
    match placeholder {
      RenderLink(link) =>
        Some(
          @html.ElementOutput::body([
            self.render_preview_link_node(link, context),
          ]),
        )
      RenderEmbed(embed, source, tree) => {
        let html = self.render_preview_embed_html(
          embed, source, tree, counter, context,
        )
        Some(@html.ElementOutput::flow([@sexp.SexpNode::Raw(html)]))
      }
    }
  }
  let options = {
    ..@html.CompileOptions::fragment(),
    wrap_inline_content,
    extensions: [resolver],
  }
  let nodes = @html.compile_fragment(
    { source: @core.SourceInfo::default(), nodes },
    options~,
  )
  @sexp.render_html_fragment(nodes)
}

///|
fn RenderState::render_preview_link_node(
  self : RenderState,
  link : ResolvedLink,
  context : PreviewRenderContext,
) -> @sexp.SexpNode raise @core.Diagnostic {
  let label = self.render_link_label(link.label)
  let id = context.next_link_id()
  match link.slug {
    Some(slug) => {
      let href = slug.url()
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
      let attrs = @sexp.Attrs({ "href": Some(href) })
      if context.options.annotate_html {
        attrs.upsert("data-altsia-link-id", Some(id))
        attrs.upsert("data-altsia-tree", Some(slug.canonical()))
        if target_source is Some(path) {
          attrs.upsert("data-altsia-target-source", Some(path))
        }
      }
      @sexp.SexpNode::Element("a", attrs, [@sexp.SexpNode::Raw(label)])
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
      let attrs = @sexp.Attrs({
        "href": Some(href),
        "data-missing-target": Some(link.target),
      })
      if context.options.annotate_html {
        attrs.upsert("data-altsia-link-id", Some(id))
      }
      @sexp.SexpNode::Element("a", attrs, [@sexp.SexpNode::Raw(label)])
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
) -> String raise @core.Diagnostic {
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
    attrs.upsert("data-altsia-embed-id", Some(id))
    attrs.upsert("data-altsia-target-source", Some(tree.path))
  }
  let body_html = self.render_preview_tree_body(tree, context)
  let number = if embed.option.numbering { Some(counter.next()) } else { None }
  let catalog = if embed.option.catalog {
    self.render_embed_catalog(tree)
  } else {
    None
  }
  let nodes = match embed.title {
    Some(title) => {
      if embed.option.details_open {
        attrs.upsert("open", None)
      }
      let summary_children = embed_summary_children(title, number)
      let children : Array[@sexp.SexpNode] = [
        @sexp.SexpNode::Element(
          "summary",
          @sexp.Attrs(Map([])),
          summary_children,
        ),
        @sexp.SexpNode::Raw(body_html),
      ]
      if catalog is Some(node) {
        children.push(node)
      }
      [@sexp.SexpNode::Element("details", attrs, children)]
    }
    None => {
      let children : Array[@sexp.SexpNode] = []
      if number is Some(number) {
        children.push(
          @sexp.SexpNode::Element(
            "div",
            @sexp.Attrs({ "class": Some("embed-number") }),
            [@sexp.SexpNode::Text(number.to_string() + ".")],
          ),
        )
      }
      children.push(@sexp.SexpNode::Raw(body_html))
      if catalog is Some(node) {
        children.push(node)
      }
      [@sexp.SexpNode::Element("div", attrs, children)]
    }
  }
  @sexp.render_html_fragment(nodes)
}

///|
fn RenderState::source_path_for_slug(
  self : RenderState,
  slug : @model.TreeSlug,
) -> String? {
  self.input.source_trees_by_slug.get(slug.canonical()).map(tree => tree.path)
}
