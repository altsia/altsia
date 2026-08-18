///|
fn embed_summary_children(
  title : String,
  number : Int?,
) -> Array[@sexp.SexpNode] {
  match number {
    Some(number) =>
      [
        @sexp.SexpNode::Element(
          "span",
          @sexp.Attrs({ "class": Some("embed-number") }),
          [@sexp.SexpNode::Text(number.to_string() + ".")],
        ),
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
        @sexp.Attrs({
          "class": Some("embed-catalog"),
          "aria-label": Some("Embedded content"),
        }),
        [@sexp.SexpNode::Element("ol", @sexp.Attrs(Map([])), items)],
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
              @sexp.Attrs({ "href": Some(child.slug.url()) }),
              [@sexp.SexpNode::Text(self.tree_footer_label(child_key))],
            ),
          ]
          if !children.is_empty() {
            content.push(
              @sexp.SexpNode::Element("ol", @sexp.Attrs(Map([])), children),
            )
          }
          items.push(
            @sexp.SexpNode::Element("li", @sexp.Attrs(Map([])), content),
          )
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
fn embed_attrs(
  embed : @model.EmbedDirective,
  resolved_key : String,
) -> @sexp.Attrs {
  let attrs = @sexp.Attrs({
    "class": Some("embed"),
    "data-tree": Some(resolved_key),
  })
  if embed.option.numbering {
    attrs.upsert("data-numbering", Some("true"))
  }
  if !embed.option.catalog {
    attrs.upsert("data-catalog", Some("false"))
  }
  attrs
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
