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
    push_optional_sexp_node(
      sections,
      self.footer_section("References", tree.references, tree.metadata),
    )
  }
  if tree.metadata.show_backlinks {
    push_optional_sexp_node(
      sections,
      self.footer_section("Backlinks", tree.backlinks, tree.metadata),
    )
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
