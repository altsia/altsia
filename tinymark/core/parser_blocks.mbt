///|
fn parse_list_sugar(cursor : Cursor) -> Result[(Node, Cursor), Diagnostic] {
  guard cursor.peek() is Some(marker) else {
    return Err(cursor.error("expected list marker"))
  }
  let tag = if marker == '-' { "list" } else { "enum" }
  let items : Array[Node] = []
  let mut scan = cursor
  while !scan.is_end() && scan.at_line_start() && scan.peek() == Some(marker) {
    let content_start = scan.advance(1)
    let mut line_end = content_start.index
    while line_end < scan.length() && !is_line_end(scan.char_at(line_end)) {
      line_end += 1
    }
    let (item_start, item_end) = trim_line_bounds(
      scan,
      content_start.index,
      line_end,
    )
    let item_text = scan.slice_to_string(item_start, item_end)
    let (line, column) = scan.at(item_start).line_column()
    let parsed_line = parse_nodes_at(
      item_text,
      scan.source_span().source_id,
      line - 1,
      column - 1,
    )
    match parsed_line {
      Ok(children) =>
        items.push(Node::Element("item", [], children, scan.source_span()))
      Err(error) => return Err(error)
    }
    scan = scan.at(line_end)
    if scan.peek().map(is_newline).unwrap_or(false) {
      scan = scan.advance(1)
    }
  }
  Ok((Node::Element(tag, [], items, cursor.source_span()), scan))
}

///|
fn maybe_attach_block_quote(node : Node, cursor : Cursor) -> (Node, Cursor) {
  let (candidate, blocked) = skip_attach_space(cursor)
  if blocked || !is_block_quote_fence_start(candidate) {
    return (node, cursor)
  }
  guard parse_block_quote(candidate) is Ok((content, next)) else {
    return (node, cursor)
  }
  match node {
    Element(tag, attrs, children, span) => {
      children.push(Node::Text(content, candidate.source_span()))
      (Node::Element(tag, attrs, children, span), next)
    }
    Ref(name, span) =>
      (
        Node::Element(
          name,
          [],
          [Node::Text(content, candidate.source_span())],
          span,
        ),
        next,
      )
    _ => (node, cursor)
  }
}

///|
fn parse_block_quote(cursor : Cursor) -> Result[(String, Cursor), Diagnostic] {
  let mut fence_end = cursor.index
  while fence_end < cursor.length() && !is_line_end(cursor.char_at(fence_end)) {
    fence_end += 1
  }
  let fence = cursor.slice_to_string(cursor.index, fence_end)
  if !is_block_quote_fence(fence) {
    return Err(cursor.error("expected block quote fence"))
  }
  let content_start = if fence_end < cursor.length() {
    fence_end + 1
  } else {
    fence_end
  }
  let mut index = content_start
  while index < cursor.length() {
    if is_line_start_at(cursor, index) {
      let line_end = find_line_end(cursor, index)
      let line = cursor.slice_to_string(index, line_end)
      if line == fence {
        return Ok(
          (cursor.slice_to_string(content_start, index), cursor.at(line_end)),
        )
      }
    }
    index += 1
  }
  Err(cursor.error("unterminated block quote"))
}

///|
fn find_line_end(cursor : Cursor, start : Int) -> Int {
  let mut index = start
  while index < cursor.length() && !is_line_or_list_end(cursor.char_at(index)) {
    index += 1
  }
  index
}

///|
fn trim_line_bounds(cursor : Cursor, start : Int, end : Int) -> (Int, Int) {
  let mut trimmed_start = start
  while trimmed_start < end && is_trim_space(cursor.char_at(trimmed_start)) {
    trimmed_start += 1
  }
  let mut trimmed_end = end
  while trimmed_end > trimmed_start &&
        is_trim_space(cursor.char_at(trimmed_end - 1)) {
    trimmed_end -= 1
  }
  (trimmed_start, trimmed_end)
}
