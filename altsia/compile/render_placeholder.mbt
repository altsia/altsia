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
  {
    name: "data-index",
    value: Some(Scalar(Text(index.to_string()), span)),
    span,
  }
}

///|
fn placeholder_tag() -> String {
  "altsia.placeholder"
}
