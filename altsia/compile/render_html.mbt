///|
fn RenderState::render_embed_html(
  self : RenderState,
  embed : @model.EmbedDirective,
  tree : ResolvedTree,
  counter : RenderCounter,
) -> Result[String, @core.Diagnostic] {
  let resolved_key = tree.slug.canonical()
  let attrs = embed_attrs(embed, resolved_key)
  self
  .render_resolved_tree_body(tree)
  .map(body_html => {
    let number = if embed.option.numbering {
      Some(counter.next())
    } else {
      None
    }
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
            @sexp.HtmlAttrs(Map([])),
            summary_children,
          ),
          @sexp.SexpNode::RawHtml(body_html),
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
              @sexp.HtmlAttrs({ "class": Some("embed-number") }),
              [@sexp.SexpNode::Text(number.to_string() + ".")],
            ),
          )
        }
        children.push(@sexp.SexpNode::RawHtml(body_html))
        if catalog is Some(node) {
          children.push(node)
        }
        [@sexp.SexpNode::Element("div", attrs, children)]
      }
    }
    @sexp.render_html_fragment(nodes)
  })
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
  let resolver : @html.ElementResolver = compiler => {
    if compiler.call.tag != placeholder_tag() {
      return Ok(None)
    }
    let index = next_placeholder[0]
    next_placeholder[0] = index + 1
    guard placeholders.get(index) is Some(placeholder) else {
      return Err(
        @model.diagnostic(
          compiler.call.span,
          Binding,
          "missing render placeholder",
        ),
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
          Some(@html.ElementOutput::flow([@sexp.SexpNode::RawHtml(html)]))
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
  ).map(nodes => @sexp.render_html_fragment(nodes))
}

///|
fn RenderState::render_link_node(
  self : RenderState,
  link : ResolvedLink,
) -> Result[@sexp.SexpNode, @core.Diagnostic] {
  self
  .render_link_label(link.label)
  .map(label => {
    match link.slug {
      Some(slug) =>
        Element(
          "a",
          @sexp.HtmlAttrs({ "href": Some(@model.url_for_tree(slug)) }),
          [RawHtml(label)],
        )
      None =>
        Element(
          "a",
          @sexp.HtmlAttrs({
            "href": Some("#"),
            "data-missing-target": Some(link.target),
          }),
          [RawHtml(label)],
        )
    }
  })
}

///|
fn RenderState::render_link_label(
  self : RenderState,
  label : ResolvedLinkLabel,
) -> Result[String, @core.Diagnostic] {
  match label {
    LinkText(value) => Ok(@sexp.render_html_fragment([Text(value)]))
    LinkResolvedContent(contents) =>
      self.render_resolved_content_nodes(
        contents.nodes,
        RenderCounter::new(),
        wrap_inline_content=contents.wrap_inline_content,
      )
    LinkFallbackText(value) => Ok(@sexp.render_html_fragment([Text(value)]))
  }
}

///|
fn RenderState::compiled_tree_index(
  self : RenderState,
) -> Result[Map[String, @model.CompiledTree], @core.Diagnostic] {
  let index : Map[String, @model.CompiledTree] = Map([])
  for slug in self.input.tree_order {
    if self.resolved_by_slug.get(slug) is Some(tree) {
      match self.to_compiled_tree(tree) {
        Ok(compiled) => index[slug] = compiled
        Err(error) => return Err(error)
      }
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
  self
  .render_resolved_tree_body(tree)
  .map(html => {
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
  })
}

///|
fn RenderState::ordered_compiled_trees(
  self : RenderState,
  compiled_tree_index : Map[String, @model.CompiledTree],
) -> Array[@model.CompiledTree] {
  let ordered : Array[@model.CompiledTree] = []
  for slug in self.input.tree_order {
    if compiled_tree_index.get(slug) is Some(tree) {
      ordered.push(tree)
    }
  }
  ordered
}
