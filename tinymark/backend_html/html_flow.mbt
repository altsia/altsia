///|
fn append_paragraph_content_node(
  inline_run : Array[HtmlNode],
  out : Array[HtmlNode],
  node : HtmlNode,
) -> Unit {
  match node {
    HtmlNode::Text(text) if @core.has_paragraph_break(text) =>
      append_text_with_paragraph_splits(inline_run, out, text)
    _ => inline_run.push(node)
  }
}

///|
fn flush_paragraph(inline_run : Array[HtmlNode], out : Array[HtmlNode]) -> Unit {
  if !inline_run.is_empty() {
    if inline_run_only_blank_text(inline_run) {
      out.append(inline_run.copy())
    } else {
      out.push(HtmlNode::Element("p", @sexp.HtmlAttrs({}), inline_run.copy()))
    }
    inline_run.clear()
  }
}

///|
fn inline_run_only_blank_text(inline_run : Array[HtmlNode]) -> Bool {
  for node in inline_run {
    match node {
      HtmlNode::Text(text) if text.is_blank() => ()
      _ => return false
    }
  }
  true
}

///|
fn append_text_with_paragraph_splits(
  inline_run : Array[HtmlNode],
  out : Array[HtmlNode],
  text : String,
) -> Unit {
  for part in @core.split_paragraph_text(text) {
    match part {
      @core.ParagraphPart::Text(text) => inline_run.push(HtmlNode::Text(text))
      @core.ParagraphPart::Break => flush_paragraph(inline_run, out)
    }
  }
}
