//! Leaf-block parsers: HTML blocks, code blocks, metadata blocks, and
//! list/container bookkeeping.

///|
/// When start_ix is at the beginning of an HTML block of type 1 to 5,
/// this will find the end of the block.
fn FirstPass::parse_html_block_type_1_to_5(
  self : FirstPass,
  start_ix : Int,
  html_end_tag : String,
  remaining_space : Int,
  indent : Int,
) -> Int {
  let mut remaining_space = remaining_space
  let mut indent = indent
  ignore(self.tree.append(Item::{ start: start_ix, end: 0, body: HtmlBlock, }))
  ignore(self.tree.push())

  let bytes = self.text
  let mut ix = start_ix
  let mut end_ix = 0
  while true {
    let line_start_ix = ix
    ix += scan_nextline(bytes.exact_view(start=ix))
    self.append_html_line(remaining_space.max(indent), line_start_ix, ix)

    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let n_containers = line_start.scan_containers(self.tree, self.options)
    guard n_containers >= self.tree.spine_len() else {
      end_ix = ix
      break
    }

    guard !bytes_contains_str(self.text, line_start_ix, ix, html_end_tag) else {
      end_ix = ix
      break
    }

    let next_line_ix = ix + line_start.bytes_scanned()
    guard next_line_ix != self.text.length() else {
      end_ix = next_line_ix
      break
    }
    ix = next_line_ix
    remaining_space = line_start.remaining_space()
    indent = 0
  }
  self.pop(end_ix)
  ix
}

///|
/// When start_ix is at the beginning of an HTML block of type 6 or 7.
fn FirstPass::parse_html_block_type_6_or_7(
  self : FirstPass,
  start_ix : Int,
  remaining_space : Int,
  indent : Int,
) -> Int {
  let mut remaining_space = remaining_space
  let mut indent = indent
  ignore(self.tree.append(Item::{ start: start_ix, end: 0, body: HtmlBlock, }))
  ignore(self.tree.push())

  let bytes = self.text
  let mut ix = start_ix
  let mut end_ix = 0
  while true {
    let line_start_ix = ix
    ix += scan_nextline(bytes.exact_view(start=ix))
    self.append_html_line(remaining_space.max(indent), line_start_ix, ix)

    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let n_containers = line_start.scan_containers(self.tree, self.options)
    let at_eol = line_start.is_at_eol()
    guard n_containers >= self.tree.spine_len() && !at_eol else {
      end_ix = ix
      break
    }

    let next_line_ix = ix + line_start.bytes_scanned()
    let is_end = next_line_ix == self.text.length() ||
      scan_blank_line(bytes.exact_view(start=next_line_ix)) is Some(_)
    guard !is_end else {
      end_ix = next_line_ix
      break
    }
    ix = next_line_ix
    remaining_space = line_start.remaining_space()
    indent = 0
  }
  self.pop(end_ix)
  ix
}

///|
fn FirstPass::parse_indented_code_block(
  self : FirstPass,
  start_ix : Int,
  remaining_space : Int,
) -> Int {
  let mut remaining_space = remaining_space
  ignore(
    self.tree.append(Item::{ start: start_ix, end: 0, body: IndentCodeBlock, }),
  )
  ignore(self.tree.push())
  let bytes = self.text
  let mut last_nonblank_child : Int? = None
  let mut last_nonblank_ix = 0
  let mut end_ix = 0
  self.last_line_blank = false

  let mut ix = start_ix
  while true {
    let line_start_ix = ix
    ix += scan_nextline(bytes.exact_view(start=ix))
    self.append_code_text(remaining_space, line_start_ix, ix)

    if !self.last_line_blank {
      last_nonblank_child = self.tree.cur()
      last_nonblank_ix = ix
      end_ix = ix
    }

    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let n_containers = line_start.scan_containers(self.tree, self.options)
    let cont = n_containers >= self.tree.spine_len() &&
      (line_start.scan_space(4) || line_start.is_at_eol())
    guard cont else { break }
    let next_line_ix = ix + line_start.bytes_scanned()
    guard next_line_ix != self.text.length() else { break }
    ix = next_line_ix
    remaining_space = line_start.remaining_space()
    self.last_line_blank = scan_blank_line(bytes.exact_view(start=ix))
      is Some(_)
  }

  // Trim trailing blank lines.
  if last_nonblank_child is Some(child) {
    self.tree.nodes[child].next = None
    self.tree.nodes[child].item.end = last_nonblank_ix
  }
  self.pop(end_ix)
  ix
}

///|
fn FirstPass::parse_fenced_code_block(
  self : FirstPass,
  start_ix : Int,
  indent : Int,
  fence_ch : Byte,
  n_fence_char : Int,
) -> Int {
  let bytes = self.text
  let mut info_start = start_ix + n_fence_char
  info_start += scan_whitespace_no_nl(bytes.exact_view(start=info_start))
  let mut ix = info_start + scan_nextline(bytes.exact_view(start=info_start))
  let info_end = ix -
    scan_rev_while(bytes.exact_view(start=info_start, end=ix), c => {
      c.to_char().is_ascii_whitespace()
    })
  let info_string = unescape(
    self.text,
    info_start,
    info_end,
    self.tree.is_in_table(),
  )
  ignore(
    self.tree.append(Item::{
      start: start_ix,
      end: 0, // will get set later
      body: FencedCodeBlock(self.allocs.allocate_cow(info_string)),
    }),
  )
  ignore(self.tree.push())
  while true {
    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let n_containers = line_start.scan_containers(self.tree, self.options)
    guard n_containers >= self.tree.spine_len() else {
      // this line will get parsed again as not being part of the code
      self.pop(ix)
      return ix
    }
    ignore(line_start.scan_space(indent))
    let close_line_start = line_start.clone()
    if !close_line_start.scan_space(4 - indent) {
      let close_ix = ix + close_line_start.bytes_scanned()
      if scan_closing_code_fence(
          bytes.exact_view(start=close_ix),
          fence_ch,
          n_fence_char,
        )
        is Some(n) {
        ix = close_ix + n
        self.pop(ix)
        // try to read trailing whitespace or it will register as a completely blank line
        return scan_blank_line(bytes.exact_view(start=ix)).map_or(ix, blank => {
          ix + blank
        })
      }
    }
    let remaining_space = line_start.remaining_space()
    ix += line_start.bytes_scanned()
    let next_ix = ix + scan_nextline(bytes.exact_view(start=ix))
    self.append_code_text(remaining_space, ix, next_ix)
    ix = next_ix
  }
  ix
}

///|
fn FirstPass::parse_metadata_block(
  self : FirstPass,
  start_ix : Int,
  metadata_block_ch : Byte,
) -> Int {
  let bytes = self.text
  let metadata_block_kind = if metadata_block_ch == b'-' {
    YamlStyle
  } else {
    PlusesStyle
  }
  // 3 delimiter characters
  let mut ix = start_ix +
    3 +
    scan_nextline(bytes.exact_view(start=start_ix + 3))
  ignore(
    self.tree.append(Item::{
      start: start_ix,
      end: 0, // will get set later
      body: MetadataBlock(metadata_block_kind),
    }),
  )
  ignore(self.tree.push())
  while true {
    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let n_containers = line_start.scan_containers(self.tree, self.options)
    guard n_containers >= self.tree.spine_len() else { break }
    let (indent, _) = calc_indent(bytes.exact_view(start=ix), 4)
    if indent == 0 {
      if scan_closing_metadata_block(
          bytes.exact_view(start=ix),
          metadata_block_ch,
        )
        is Some(n) {
        ix += n
        break
      }
    }
    let remaining_space = line_start.remaining_space()
    ix += line_start.bytes_scanned()
    let next_ix = ix + scan_nextline(bytes.exact_view(start=ix))
    self.append_code_text(remaining_space, ix, next_ix)
    ix = next_ix
  }

  self.pop(ix)

  // try to read trailing whitespace or it will register as a completely blank line
  scan_blank_line(bytes.exact_view(start=ix)).map_or(ix, n => ix + n)
}

///|
fn FirstPass::append_code_text(
  self : FirstPass,
  remaining_space : Int,
  start : Int,
  end : Int,
) -> Unit {
  let mut start = start
  if remaining_space > 0 {
    let spaces = String::repeat(" ", remaining_space)
    let cow_ix = self.allocs.allocate_cow(spaces)
    ignore(
      self.tree.append(Item::{
        start,
        end: start,
        body: SynthesizeText(cow_ix),
      }),
    )
  }
  while true {
    guard bytes_find_byte(self.text, start, end, 0) is Some(offset) else {
      break
    }
    self.tree.append_text(start, start + offset, false)
    ignore(
      self.tree.append(Item::{
        start: start + offset,
        end: start + offset + 1,
        body: SynthesizeChar('\u{fffd}'),
      }),
    )
    start += offset + 1
  }
  if self.text.unsafe_get(end - 2) == b'\r' {
    // Normalize CRLF to LF
    self.tree.append_text(start, end - 2, false)
    self.tree.append_text(end - 1, end, false)
  } else {
    self.tree.append_text(start, end, false)
  }
}

///|
/// Appends a line of HTML to the tree.
fn FirstPass::append_html_line(
  self : FirstPass,
  remaining_space : Int,
  start : Int,
  end : Int,
) -> Unit {
  if remaining_space > 0 {
    let spaces = String::repeat(" ", remaining_space)
    let cow_ix = self.allocs.allocate_cow(spaces)
    ignore(
      self.tree.append(Item::{
        start,
        end: start,
        body: SynthesizeText(cow_ix),
      }),
    )
  }
  if self.text.unsafe_get(end - 2) == b'\r' {
    // Normalize CRLF to LF
    ignore(self.tree.append(Item::{ start, end: end - 2, body: Html, }))
    ignore(self.tree.append(Item::{ start: end - 1, end, body: Html, }))
  } else {
    ignore(self.tree.append(Item::{ start, end, body: Html, }))
  }
}

///|
/// Pop a container, setting its end.
fn FirstPass::pop(self : FirstPass, ix : Int) -> Unit {
  let cur_ix = self.tree.pop().unwrap()
  self.tree.nodes[cur_ix].item.end = ix
  if self.tree.nodes[cur_ix].item.body is DefinitionList(_) {
    fixup_end_of_definition_list(self.tree, cur_ix)
    self.begin_list_item = None
  }
  if self.tree.nodes[cur_ix].item.body
    is (List(true, _, _) | DefinitionList(true)) {
    surgerize_tight_list(self.tree, cur_ix)
    self.begin_list_item = None
  }
}

///|
/// Close a list if it's open. Also set loose if last line was blank
/// and end current list if it's a lone, empty item
fn FirstPass::finish_list(self : FirstPass, ix : Int) -> Unit {
  self.finish_empty_list_item()
  if self.tree.peek_up() is Some(node_ix) {
    if self.tree.nodes[node_ix].item.body is (List(_, _, _) | DefinitionList(_)) {
      self.pop(ix)
    }
  }
  if self.last_line_blank {
    if self.tree.peek_grandparent() is Some(node_ix) {
      match self.tree.nodes[node_ix].item.body {
        List(_, ch, index) =>
          self.tree.nodes[node_ix].item.body = List(false, ch, index)
        DefinitionList(_) =>
          self.tree.nodes[node_ix].item.body = DefinitionList(false)
        _ => ()
      }
    }
    self.last_line_blank = false
  }
}

///|
fn FirstPass::finish_empty_list_item(self : FirstPass) -> Unit {
  if self.begin_list_item is Some(begin_list_item) && self.last_line_blank {
    // A list item can begin with at most one blank line.
    if self.tree.peek_up() is Some(node_ix) {
      if self.tree.nodes[node_ix].item.body
        is (ListItem(_) | DefinitionListDefinition(_)) {
        self.pop(begin_list_item)
      }
    }
  }
  self.begin_list_item = None
}

///|
/// Continue an existing list or start a new one if there's not an open
/// list that matches.
fn FirstPass::continue_list(
  self : FirstPass,
  start : Int,
  ch : Byte,
  index : Int64,
) -> Unit {
  self.finish_empty_list_item()
  if self.tree.peek_up() is Some(node_ix) {
    if self.tree.nodes[node_ix].item.body is List(_, existing_ch, index) &&
      existing_ch == ch {
      if self.last_line_blank {
        self.tree.nodes[node_ix].item.body = List(false, existing_ch, index)
        self.last_line_blank = false
      }
      return
    }
    self.finish_list(start)
  }
  ignore(
    self.tree.append(Item::{ start, end: 0, body: List(true, ch, index), }),
  )
  ignore(self.tree.push())
  self.last_line_blank = false
}

///|
/// Parse a thematic break.
fn FirstPass::parse_hrule(self : FirstPass, hrule_size : Int, ix : Int) -> Int {
  ignore(
    self.tree.append(Item::{ start: ix, end: ix + hrule_size, body: Rule, }),
  )
  ix + hrule_size
}
