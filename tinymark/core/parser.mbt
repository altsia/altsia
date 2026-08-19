///|
pub type Parser

///|
priv struct ParsedNodes {
  nodes : Array[Node]
  next : Cursor
}

///|
pub fn parse(
  source : String,
  source_info? : SourceInfo,
) -> Document raise Diagnostic {
  let info = source_info.unwrap_or(SourceInfo::default())
  let result = parse_node_sequence(Cursor::new(source, info), None)
  { source: info, nodes: result.nodes }
}

///|
pub fn parse_abort(source : String) -> Document {
  parse(source) catch {
    diagnostic => abort(diagnostic.render())
  }
}

///|
fn parse_nodes_at(
  source : String,
  source_id : String?,
  line_offset : Int,
  column_offset : Int,
) -> Array[Node] raise Diagnostic {
  let source_info : SourceInfo = { id: source_id, line_offset, column_offset }
  parse_node_sequence(Cursor::new(source, source_info), None).nodes
}

///|
fn parse_node_sequence(
  start : Cursor,
  close : Char?,
) -> ParsedNodes raise Diagnostic {
  let nodes : Array[Node] = []
  let mut cursor = skip_content_layout(start, close, true)
  while !cursor.is_end() {
    match close {
      Some(ch) if cursor.peek() == Some(ch) =>
        return { nodes, next: cursor.advance(1) }
      _ => ()
    }
    if cursor.peek() == Some(')') {
      raise cursor.error("unexpected ')'")
    }
    let (node, next) = parse_node(cursor)
    let (attached, after_attach) = maybe_attach_block_quote(node, next)
    nodes.push(attached)
    cursor = skip_content_layout(after_attach, close, false)
  }
  match close {
    Some(_) => raise start.error("unterminated list")
    None => { nodes, next: cursor }
  }
}

///|
fn parse_node(cursor : Cursor) -> (Node, Cursor) raise Diagnostic {
  let start = cursor
  if Parser::is_line_comment_start(start, start.index) {
    return parse_node(skip_content_layout(skip_line_comment(start), None, true))
  }
  if start.at_line_start() &&
    start.peek().map(Parser::is_list_sugar_marker).unwrap_or(false) {
    return parse_list_sugar(start)
  }
  match start.peek() {
    None => raise start.error("unexpected end of input")
    Some('(') => parse_list(start)
    Some('`') => {
      let (text, next) = parse_raw_string(start)
      (Node::Text(text, start.source_span()), next)
    }
    Some('"') => {
      let (text, next) = parse_quoted_string(start)
      (Node::TextInterp(text, start.source_span()), next)
    }
    Some('*') => parse_emphasis_or_text(start)
    _ => {
      let (text, next) = parse_text(start)
      (Node::Text(text, start.source_span()), next)
    }
  }
}

///|
fn parse_list(open : Cursor) -> (Node, Cursor) raise Diagnostic {
  let head_start = open.advance(1).skip_layout()
  let (head, after_head) = parse_name(head_start)
  if head.is_empty() {
    raise head_start.error("list head cannot be empty")
  }
  match head {
    "def" => parse_def(head_start, after_head)
    "let" => parse_let(head_start, after_head)
    "doc" => parse_doc_call(head_start, after_head)
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
) -> (Node, Cursor) raise Diagnostic {
  let name_start = after_head.skip_layout()
  let (name, after_name) = parse_name(name_start)
  if name.is_empty() {
    raise name_start.error("def name cannot be empty")
  }
  let params_start = after_name.skip_layout()
  if params_start.peek() != Some('(') {
    raise params_start.error("def requires a parameter list")
  }
  let (params, after_params) = parse_param_list(params_start)
  let body : Array[Node] = []
  let mut cursor = skip_content_layout(after_params, Some(')'), true)
  while !cursor.is_end() && cursor.peek() != Some(')') {
    let (node, next) = parse_node(cursor)
    body.push(node)
    cursor = skip_content_layout(next, Some(')'), false)
  }
  if cursor.peek() != Some(')') {
    raise after_head.error("unterminated def")
  }
  (Node::Def(name, params, body, head_start.source_span()), cursor.advance(1))
}

///|
fn parse_let(
  head_start : Cursor,
  after_head : Cursor,
) -> (Node, Cursor) raise Diagnostic {
  let name_start = after_head.skip_layout()
  let (name, after_name) = parse_name(name_start)
  if name.is_empty() {
    raise name_start.error("let name cannot be empty")
  }
  let values : Array[Node] = []
  let mut cursor = skip_content_layout(after_name, Some(')'), true)
  while !cursor.is_end() && cursor.peek() != Some(')') {
    let (node, next) = parse_node(cursor)
    values.push(node)
    cursor = skip_content_layout(next, Some(')'), false)
  }
  if cursor.peek() != Some(')') {
    raise after_head.error("unterminated let")
  }
  let value = nodes_to_value_at(values, after_name.skip_layout().source_span())
  (Node::Let(name, value, head_start.source_span()), cursor.advance(1))
}

///|
fn parse_param_list(open : Cursor) -> (Array[String], Cursor) raise Diagnostic {
  let params : Array[String] = []
  let mut cursor = open.advance(1).skip_layout()
  while !cursor.is_end() && cursor.peek() != Some(')') {
    let (name, next) = parse_name(cursor)
    if name.is_empty() {
      raise cursor.error("parameter name cannot be empty")
    }
    if params.contains(name) {
      raise cursor.error("duplicate parameter name: " + name)
    }
    params.push(name)
    cursor = next.skip_layout()
  }
  if cursor.peek() != Some(')') {
    raise open.error("unterminated parameter list")
  }
  (params, cursor.advance(1))
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
    "true" => Scalar(Bool(true), span)
    "false" => Scalar(Bool(false), span)
    _ => Scalar(Text(text), span)
  }
}

///|
fn parse_doc_call(
  head_start : Cursor,
  after_head : Cursor,
) -> (Node, Cursor) raise Diagnostic {
  let cursor = after_head.skip_layout()
  match cursor.peek() {
    Some('(') => {
      let (attrs, next) = parse_attr_list(cursor)
      let end = next.skip_layout()
      guard end.peek() == Some(')') else {
        raise end.error("doc only accepts an attribute list")
      }
      (Node::Doc(attrs, head_start.source_span()), end.advance(1))
    }
    _ => raise cursor.error("doc requires an attribute list")
  }
}

///|
fn parse_conditional(
  head_start : Cursor,
  after_head : Cursor,
  is_when : Bool,
) -> (Node, Cursor) raise Diagnostic {
  let condition_start = after_head.skip_layout()
  let (name, after_condition) = parse_condition_ref(condition_start)
  let result = parse_node_sequence(after_condition, Some(')'))
  let node = if is_when {
    Node::When(name, result.nodes, head_start.source_span())
  } else {
    Node::Unless(name, result.nodes, head_start.source_span())
  }
  (node, result.next)
}

///|
fn parse_condition_ref(cursor : Cursor) -> (String, Cursor) raise Diagnostic {
  if cursor.peek() != Some('(') {
    raise cursor.error("condition must be a zero-argument name reference")
  }
  let (name, after_name) = parse_name(cursor.advance(1).skip_layout())
  let end = after_name.skip_layout()
  if name.is_empty() || end.peek() != Some(')') {
    raise cursor.error("condition must be a zero-argument name reference")
  }
  (name, end.advance(1))
}

///|
fn parse_element_or_ref(
  tag : String,
  head_start : Cursor,
  after_head : Cursor,
) -> (Node, Cursor) raise Diagnostic {
  let mut cursor = after_head.skip_layout()
  let attrs : Array[Attr] = []
  if cursor.peek() == Some('(') {
    if peek_attr_list(cursor) {
      let (parsed_attrs, next) = parse_attr_list(cursor)
      attrs.append(parsed_attrs)
      cursor = next.skip_layout()
    }
  }
  let result = parse_node_sequence(cursor, Some(')'))
  let node = if attrs.is_empty() && result.nodes.is_empty() {
    Node::Ref(tag, head_start.source_span())
  } else {
    Node::Element(tag, attrs, result.nodes, head_start.source_span())
  }
  (node, result.next)
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
fn parse_attr_list(open : Cursor) -> (Array[Attr], Cursor) raise Diagnostic {
  let attrs : Array[Attr] = []
  let mut cursor = open.advance(1).skip_layout()
  while !cursor.is_end() {
    cursor = cursor.skip_layout()
    match cursor.peek() {
      Some(')') => return (attrs, cursor.advance(1))
      Some(':') => {
        let (attr, next) = parse_single_attr(cursor)
        attrs.push(attr)
        cursor = next
      }
      _ => raise cursor.error("expected attribute key")
    }
  }
  raise open.error("unterminated attribute list")
}

///|
fn parse_single_attr(cursor : Cursor) -> (Attr, Cursor) raise Diagnostic {
  let (name, after_name) = parse_name(cursor.advance(1))
  if name.is_empty() {
    raise cursor.error("attribute name cannot be empty")
  }
  let value_start = after_name.skip_layout()
  let span = cursor.source_span()
  match value_start.peek() {
    Some(')') | Some(':') => ({ name, value: None, span }, value_start)
    _ => {
      let (value, next) = parse_value(value_start)
      ({ name, value: Some(value), span }, next)
    }
  }
}

///|
fn parse_value(cursor : Cursor) -> (Value, Cursor) raise Diagnostic {
  match cursor.peek() {
    Some('`') => {
      let (text, next) = parse_raw_string(cursor)
      (Value::Scalar(Text(text), cursor.source_span()), next)
    }
    Some('"') => {
      let (text, next) = parse_quoted_string(cursor)
      (Value::Interp(text, cursor.source_span()), next)
    }
    Some('(') => parse_value_ref(cursor)
    _ => {
      let (name, next) = parse_name(cursor)
      if name.is_empty() {
        raise cursor.error("expected value")
      } else {
        (scalar_or_bool(name, cursor.source_span()), next)
      }
    }
  }
}

///|
fn parse_value_ref(cursor : Cursor) -> (Value, Cursor) raise Diagnostic {
  let (name, after_name) = parse_name(cursor.advance(1).skip_layout())
  let end = after_name.skip_layout()
  if name.is_empty() || end.peek() != Some(')') {
    let diagnostic = cursor.error(
      "attribute value only accepts zero-argument name references",
    )
    raise diagnostic
  }
  (Value::Interp([Name(name)], cursor.source_span()), end.advance(1))
}
