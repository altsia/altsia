///|
priv struct ParsedNodes {
  nodes : Array[Node]
  next : Cursor
}

///|
pub fn parse(
  source : String,
  source_info? : SourceInfo,
) -> Result[Document, Diagnostic] {
  let info = source_info.unwrap_or(SourceInfo::default())
  parse_node_sequence(Cursor::new(source, info), None).map(result => {
    source: info,
    nodes: result.nodes,
  })
}

///|
fn parse_nodes_at(
  source : String,
  source_id : String?,
  line_offset : Int,
  column_offset : Int,
) -> Result[Array[Node], Diagnostic] {
  let source_info : SourceInfo = { id: source_id, line_offset, column_offset }
  parse_node_sequence(Cursor::new(source, source_info), None).map(result => {
    result.nodes
  })
}

///|
fn parse_node_sequence(
  start : Cursor,
  close : Char?,
) -> Result[ParsedNodes, Diagnostic] {
  let nodes : Array[Node] = []
  let mut cursor = skip_content_layout(start, close, true)
  while !cursor.is_end() {
    match close {
      Some(ch) if cursor.peek() == Some(ch) =>
        return Ok({ nodes, next: cursor.advance(1) })
      _ => ()
    }
    if cursor.peek() == Some(')') {
      return Err(cursor.error("unexpected ')'"))
    }
    let parsed = parse_node(cursor)
    match parsed {
      Err(error) => return Err(error)
      Ok((node, next)) => {
        let (attached, after_attach) = maybe_attach_block_quote(node, next)
        nodes.push(attached)
        cursor = skip_content_layout(after_attach, close, false)
      }
    }
  }
  match close {
    Some(_) => Err(start.error("unterminated list"))
    None => Ok({ nodes, next: cursor })
  }
}

///|
fn parse_node(cursor : Cursor) -> Result[(Node, Cursor), Diagnostic] {
  let start = cursor
  if is_line_comment_start(start, start.index) {
    return parse_node(skip_content_layout(skip_line_comment(start), None, true))
  }
  if start.at_line_start() &&
    start.peek().map(is_list_sugar_marker).unwrap_or(false) {
    return parse_list_sugar(start)
  }
  match start.peek() {
    None => Err(start.error("unexpected end of input"))
    Some('(') => parse_list(start)
    Some('`') =>
      parse_raw_string(start).map(result => {
        (Node::Text(result.0, start.source_span()), result.1)
      })
    Some('"') =>
      parse_quoted_string(start).map(result => {
        (Node::TextInterp(result.0, start.source_span()), result.1)
      })
    Some('*') => parse_emphasis_or_text(start)
    _ => {
      let (text, next) = parse_text(start)
      Ok((Node::Text(text, start.source_span()), next))
    }
  }
}

///|
fn parse_list(open : Cursor) -> Result[(Node, Cursor), Diagnostic] {
  let head_start = open.advance(1).skip_layout()
  let (head, after_head) = parse_name(head_start)
  if head.is_empty() {
    return Err(head_start.error("list head cannot be empty"))
  }
  match head {
    "def" => parse_def(head_start, after_head)
    "let" => parse_let(head_start, after_head)
    "doc" => parse_doc(head_start, after_head)
    "when" => parse_conditional(head_start, after_head, true)
    "unless" => parse_conditional(head_start, after_head, false)
    _ =>
      parse_element_or_ref(normalize_source_tag(head), head_start, after_head)
  }
}

///|
fn parse_def(
  head_start : Cursor,
  after_head : Cursor,
) -> Result[(Node, Cursor), Diagnostic] {
  let name_start = after_head.skip_layout()
  let (name, after_name) = parse_name(name_start)
  if name.is_empty() {
    return Err(name_start.error("def name cannot be empty"))
  }
  let params_start = after_name.skip_layout()
  if params_start.peek() != Some('(') {
    return Err(params_start.error("def requires a parameter list"))
  }
  let (params, after_params) = match parse_param_list(params_start) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let body : Array[Node] = []
  let mut cursor = skip_content_layout(after_params, Some(')'), true)
  while !cursor.is_end() && cursor.peek() != Some(')') {
    match parse_node(cursor) {
      Err(error) => return Err(error)
      Ok((node, next)) => {
        body.push(node)
        cursor = skip_content_layout(next, Some(')'), false)
      }
    }
  }
  if cursor.peek() != Some(')') {
    return Err(after_head.error("unterminated def"))
  }
  Ok(
    (Node::Def(name, params, body, head_start.source_span()), cursor.advance(1)),
  )
}

///|
fn parse_let(
  head_start : Cursor,
  after_head : Cursor,
) -> Result[(Node, Cursor), Diagnostic] {
  let name_start = after_head.skip_layout()
  let (name, after_name) = parse_name(name_start)
  if name.is_empty() {
    return Err(name_start.error("let name cannot be empty"))
  }
  let values : Array[Node] = []
  let mut cursor = skip_content_layout(after_name, Some(')'), true)
  while !cursor.is_end() && cursor.peek() != Some(')') {
    match parse_node(cursor) {
      Err(error) => return Err(error)
      Ok((node, next)) => {
        values.push(node)
        cursor = skip_content_layout(next, Some(')'), false)
      }
    }
  }
  if cursor.peek() != Some(')') {
    return Err(after_head.error("unterminated let"))
  }
  let value = nodes_to_value_at(values, after_name.skip_layout().source_span())
  Ok((Node::Let(name, value, head_start.source_span()), cursor.advance(1)))
}

///|
fn parse_param_list(
  open : Cursor,
) -> Result[(Array[String], Cursor), Diagnostic] {
  let params : Array[String] = []
  let mut cursor = open.advance(1).skip_layout()
  while !cursor.is_end() && cursor.peek() != Some(')') {
    let (name, next) = parse_name(cursor)
    if name.is_empty() {
      return Err(cursor.error("parameter name cannot be empty"))
    }
    if params.contains(name) {
      return Err(cursor.error("duplicate parameter name: " + name))
    }
    params.push(name)
    cursor = next.skip_layout()
  }
  if cursor.peek() != Some(')') {
    return Err(open.error("unterminated parameter list"))
  }
  Ok((params, cursor.advance(1)))
}

///|
pub fn nodes_to_value(nodes : Array[Node]) -> Value {
  nodes_to_value_at(nodes, nodes[0].span())
}

///|
fn nodes_to_value_at(nodes : Array[Node], span : SourceSpan) -> Value {
  match nodes {
    [Text(text, text_span)] => scalar_or_bool(text, text_span)
    [TextInterp(text, text_span)] => Value::Interp(text, text_span)
    _ => Value::Fragment(nodes, span)
  }
}

///|
fn scalar_or_bool(text : String, span : SourceSpan) -> Value {
  match text {
    "true" => Bool(true, span)
    "false" => Bool(false, span)
    _ => Scalar(text, span)
  }
}

///|
fn parse_doc(
  head_start : Cursor,
  after_head : Cursor,
) -> Result[(Node, Cursor), Diagnostic] {
  let cursor = after_head.skip_layout()
  match cursor.peek() {
    Some('(') =>
      parse_attr_list(cursor).bind(result => {
        let (attrs, next) = result
        let end = next.skip_layout()
        if end.peek() == Some(')') {
          Ok((Node::Doc(attrs, head_start.source_span()), end.advance(1)))
        } else {
          Err(end.error("doc only accepts an attribute list"))
        }
      })
    _ => Err(cursor.error("doc requires an attribute list"))
  }
}

///|
fn parse_conditional(
  head_start : Cursor,
  after_head : Cursor,
  is_when : Bool,
) -> Result[(Node, Cursor), Diagnostic] {
  let condition_start = after_head.skip_layout()
  parse_condition_ref(condition_start).bind(result => {
    let (name, after_condition) = result
    parse_node_sequence(after_condition, Some(')')).map(result => {
      let node = if is_when {
        Node::When(name, result.nodes, head_start.source_span())
      } else {
        Node::Unless(name, result.nodes, head_start.source_span())
      }
      (node, result.next)
    })
  })
}

///|
fn parse_condition_ref(cursor : Cursor) -> Result[(String, Cursor), Diagnostic] {
  if cursor.peek() != Some('(') {
    return Err(cursor.error("condition must be a zero-argument name reference"))
  }
  let (name, after_name) = parse_name(cursor.advance(1).skip_layout())
  let end = after_name.skip_layout()
  if name.is_empty() || end.peek() != Some(')') {
    return Err(cursor.error("condition must be a zero-argument name reference"))
  }
  Ok((name, end.advance(1)))
}

///|
fn parse_element_or_ref(
  tag : String,
  head_start : Cursor,
  after_head : Cursor,
) -> Result[(Node, Cursor), Diagnostic] {
  let mut cursor = after_head.skip_layout()
  let attrs : Array[Attr] = []
  if cursor.peek() == Some('(') {
    if peek_attr_list(cursor) {
      let (parsed_attrs, next) = match parse_attr_list(cursor) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      attrs.append(parsed_attrs)
      cursor = next.skip_layout()
    }
  }
  parse_node_sequence(cursor, Some(')')).map(result => {
    let node = if attrs.is_empty() && result.nodes.is_empty() {
      Node::Ref(tag, head_start.source_span())
    } else {
      Node::Element(tag, attrs, result.nodes, head_start.source_span())
    }
    (node, result.next)
  })
}

///|
fn peek_attr_list(cursor : Cursor) -> Bool {
  cursor.advance(1).skip_layout().peek() == Some(':')
}

///|
fn normalize_source_tag(tag : String) -> String {
  match tag {
    "-" => "item"
    _ => tag
  }
}

///|
fn parse_attr_list(open : Cursor) -> Result[(Array[Attr], Cursor), Diagnostic] {
  let attrs : Array[Attr] = []
  let mut cursor = open.advance(1).skip_layout()
  while !cursor.is_end() {
    cursor = cursor.skip_layout()
    match cursor.peek() {
      Some(')') => return Ok((attrs, cursor.advance(1)))
      Some(':') =>
        match parse_single_attr(cursor) {
          Ok((attr, next)) => {
            attrs.push(attr)
            cursor = next
          }
          Err(error) => return Err(error)
        }
      _ => return Err(cursor.error("expected attribute key"))
    }
  }
  Err(open.error("unterminated attribute list"))
}

///|
fn parse_single_attr(cursor : Cursor) -> Result[(Attr, Cursor), Diagnostic] {
  let (name, after_name) = parse_name(cursor.advance(1))
  if name.is_empty() {
    return Err(cursor.error("attribute name cannot be empty"))
  }
  let value_start = after_name.skip_layout()
  let span = cursor.source_span()
  match value_start.peek() {
    Some(')') | Some(':') => Ok(({ name, value: None, span }, value_start))
    _ =>
      parse_value(value_start).map(result => {
        let (value, next) = result
        ({ name, value: Some(value), span }, next)
      })
  }
}

///|
fn parse_value(cursor : Cursor) -> Result[(Value, Cursor), Diagnostic] {
  match cursor.peek() {
    Some('`') =>
      parse_raw_string(cursor).map(result => {
        (Value::Scalar(result.0, cursor.source_span()), result.1)
      })
    Some('"') =>
      parse_quoted_string(cursor).map(result => {
        (Value::Interp(result.0, cursor.source_span()), result.1)
      })
    Some('(') => parse_value_ref(cursor)
    _ => {
      let (name, next) = parse_name(cursor)
      if name.is_empty() {
        Err(cursor.error("expected value"))
      } else {
        Ok((scalar_or_bool(name, cursor.source_span()), next))
      }
    }
  }
}

///|
fn parse_value_ref(cursor : Cursor) -> Result[(Value, Cursor), Diagnostic] {
  let (name, after_name) = parse_name(cursor.advance(1).skip_layout())
  let end = after_name.skip_layout()
  if name.is_empty() || end.peek() != Some(')') {
    let diagnostic = cursor.error(
      "attribute value only accepts zero-argument name references",
    )
    return Err(diagnostic)
  }
  Ok((Value::Interp([Name(name)], cursor.source_span()), end.advance(1)))
}
