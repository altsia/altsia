//! Paragraph, table, and line parsing: leaf-block production inside the
//! first pass.

///|
/// Scanning modes for `parse_line`.
priv enum TableParseMode {
  /// Inside a paragraph, scanning for table headers.
  Scan
  /// Inside a table.
  Active
  /// Inside a paragraph, not scanning for table headers.
  Disabled
}

///|
/// footnote definitions and GFM quote markers can be "interrupted"
/// like paragraphs, but otherwise can't have other blocks after them.
fn FirstPass::scan_next_line_or_lazy_continuation(
  self : FirstPass,
  bytes : BytesView,
) -> LineStart? {
  let line_start = LineStart::new(bytes)
  let tree_position = line_start.scan_containers(self.tree, self.options)
  let current_container = tree_position == self.tree.spine_len()
  let interrupted = !line_start.scan_space(4) &&
    self.scan_paragraph_interrupt(
      bytes.exact_view(start=line_start.bytes_scanned()),
      current_container,
      tree_position,
    )
  let blank = scan_blank_line(
      bytes.exact_view(start=line_start.bytes_scanned()),
    )
    is Some(_)
  guard !(interrupted || blank) else { None }
  line_start.scan_all_space()
  Some(line_start)
}

///|
/// Returns the offset of the first line after the table.
fn FirstPass::parse_table(
  self : FirstPass,
  table_cols : Int,
  head_start : Int,
  body_start : Int,
) -> Int? {
  // filled empty cells are limited to protect against quadratic growth
  let missing_empty_cells = 0
  // parse header
  guard self.parse_table_row_inner(head_start, table_cols, missing_empty_cells)
    is Some((_sep_start, thead_ix)) else {
    None
  }
  self.tree.nodes[thead_ix].item.body = TableHead

  // parse body
  let mut ix = body_start
  while true {
    guard self.parse_table_row(ix, table_cols, missing_empty_cells)
      is Some((next_ix, _row_ix)) else {
      break
    }
    ix = next_ix
  }

  self.pop(ix)
  Some(ix)
}

///|
/// Call this when containers are taken care of.
/// Returns bytes scanned, row_ix
fn FirstPass::parse_table_row_inner(
  self : FirstPass,
  ix : Int,
  row_cells : Int,
  missing_empty_cells : Int,
) -> (Int, Int)? {
  let mut ix = ix
  // Limit to prevent a malicious input from causing a denial of service.
  let max_autocompleted_cells = 1 << 18

  let bytes = self.text
  let mut cells = 0
  let mut final_cell_ix : Int? = None
  let mut missing_empty_cells = missing_empty_cells

  let old_cur = self.tree.cur()
  let row_ix = self.tree.append(Item::{ start: ix, end: 0, body: TableRow, })
  ignore(self.tree.push())

  while true {
    ix += scan_ch(bytes.exact_view(start=ix), b'|')
    let start_ix = ix
    ix += scan_whitespace_no_nl(bytes.exact_view(start=ix))

    if scan_eol(bytes.exact_view(start=ix)) is Some(eol_bytes) {
      ix += eol_bytes
      break
    }

    let cell_ix = self.tree.append(Item::{
      start: start_ix,
      end: ix,
      body: TableCell,
    })
    ignore(self.tree.push())
    let (next_ix, _brk) = self.parse_line(ix, None, Active)

    self.tree.nodes[cell_ix].item.end = next_ix
    ignore(self.tree.pop())

    ix = next_ix
    cells += 1

    if cells == row_cells {
      final_cell_ix = Some(cell_ix)
    }
  }

  if old_cur is Some(cur) {
    if cells == 0 {
      ignore(self.pop(ix))
      self.tree.nodes[cur].next = None
      return None
    }
  }

  // fill empty cells if needed
  for _ in cells..<row_cells {
    guard missing_empty_cells < max_autocompleted_cells else { return None }
    missing_empty_cells += 1
    ignore(self.tree.append(Item::{ start: ix, end: ix, body: TableCell, }))
  }

  // drop excess cells
  if final_cell_ix is Some(cell_ix) {
    self.tree.nodes[cell_ix].next = None
  }

  ignore(self.pop(ix))

  Some((ix, row_ix))
}

///|
/// Returns first offset after the row and the tree index of the row.
fn FirstPass::parse_table_row(
  self : FirstPass,
  ix : Int,
  row_cells : Int,
  missing_empty_cells : Int,
) -> (Int, Int)? {
  let mut ix = ix
  let bytes = self.text
  let line_start = LineStart::new(bytes.exact_view(start=ix))
  let tree_position = line_start.scan_containers(self.tree, self.options)
  let current_container = tree_position == self.tree.spine_len()
  guard current_container else { return None }
  line_start.scan_all_space()
  ix += line_start.bytes_scanned()
  guard !scan_paragraph_interrupt_no_table(
    bytes.exact_view(start=ix),
    current_container,
    self.options.contains(enable_footnotes()),
    self.options.contains(enable_definition_list()),
    self.tree,
    tree_position,
  ) else {
    return None
  }

  self.parse_table_row_inner(ix, row_cells, missing_empty_cells)
}

///|
/// Returns offset of line start after paragraph.
fn FirstPass::parse_paragraph(
  self : FirstPass,
  start_ix : Int,
  tasklist_marker : Item?,
) -> Int {
  let body = {
    guard self.tree.peek_up() is Some(idx) else {
      self.finish_list(start_ix)
      Paragraph
    }
    let is_deflist = self.tree.nodes[idx].item.body is DefinitionList(_)
    let cur_is_def = self.tree
      .cur()
      .map_or(true, idx2 => {
        self.tree.nodes[idx2].item.body is DefinitionListDefinition(_)
      })
    if is_deflist && cur_is_def {
      // blank lines between the previous definition and this one don't count
      self.last_line_blank = false
      MaybeDefinitionListTitle
    } else {
      self.finish_list(start_ix)
      Paragraph
    }
  }
  let node_ix = self.tree.append(Item::{ start: start_ix, end: 0, body, })
  ignore(self.tree.push())

  if tasklist_marker is Some(item) {
    ignore(self.tree.append(item))
  }

  let bytes = self.text
  let mut ix = start_ix
  while true {
    let scan_mode = if self.options.contains(enable_tables()) && ix == start_ix {
      Scan
    } else {
      Disabled
    }
    let (next_ix, brk) = self.parse_line(ix, None, scan_mode)

    // break out when we find a table
    if brk is Some(brk_item) {
      if brk_item.body is Table(alignment_ix) {
        let table_cols = self.allocs.alignments[alignment_ix].length()
        self.tree.nodes[node_ix].item.body = Table(alignment_ix)
        // this clears out any stuff we may have appended
        self.tree.nodes[node_ix].child = None
        ignore(self.tree.pop())
        let is_maybe_title = body is MaybeDefinitionListTitle
        if is_maybe_title {
          self.finish_list(ix)
        }
        ignore(self.tree.push())
        if self.parse_table(table_cols, ix, next_ix) is Some(result) {
          return result
        }
      }
    }

    ix = next_ix
    let line_start = LineStart::new(bytes.exact_view(start=ix))
    let tree_position = line_start.scan_containers(self.tree, self.options)
    let current_container = tree_position == self.tree.spine_len()

    let trailing_backslash_pos = if brk is Some(brk_item) &&
      brk_item.body is HardBreak(true) &&
      bytes.length() > brk_item.start &&
      bytes.unsafe_get(brk_item.start) == b'\\' {
      Some(brk_item.start)
    } else {
      None
    }
    if !line_start.scan_space(4) {
      let ix_new = ix + line_start.bytes_scanned()
      if current_container {
        if self.parse_setext_heading(
            ix_new,
            node_ix,
            trailing_backslash_pos is Some(_),
          )
          is Some(ix_setext) {
          if trailing_backslash_pos is Some(pos) {
            self.tree.append_text(pos, pos + 1, false)
          }
          self.pop(ix_setext)
          let is_maybe_title = body is MaybeDefinitionListTitle
          if is_maybe_title {
            self.finish_list(ix)
          }
          return ix_setext
        }
      }
      // first check for non-empty lists, then for other interrupts
      let suffix = bytes.exact_view(start=ix_new)
      if self.scan_paragraph_interrupt(suffix, current_container, tree_position) {
        if trailing_backslash_pos is Some(pos) {
          self.tree.append_text(pos, pos + 1, false)
        }
        break
      }
      let close_container = self.options.contains(enable_container_extensions()) &&
        !current_container &&
        line_start.scan_closing_container_extensions_fence(3)
      guard !close_container else { break }
    }
    line_start.scan_all_space()
    if line_start.is_at_eol() {
      if trailing_backslash_pos is Some(pos) {
        self.tree.append_text(pos, pos + 1, false)
      }
      break
    }

    if self.options.contains(enable_container_extensions()) {
      let closes = closes_container(self.tree, line_start)
      guard !closes else { break }
    }

    ix = next_ix + line_start.bytes_scanned()
    if brk is Some(item) {
      ignore(self.tree.append(item))
    }
  }

  self.pop(ix)
  ix
}

///|
/// True when `line_start` scans a closing container-extension fence on the
/// spine: walk from the innermost node, and a closing fence on a container
/// closes every container above it.
fn closes_container(tree : Tree[Item], line_start : LineStart) -> Bool {
  let spine = tree.walk_spine()
  for idx in 1..<spine.length() {
    let node_ix = spine[spine.length() - 1 - idx]
    match tree.nodes[node_ix].item.body {
      Container(length, _, _) =>
        if line_start.scan_closing_container_extensions_fence(length) {
          return true
        }
      _ => return false
    }
  }
  false
}

///|
/// Mutable state for `parse_line`.
priv struct LineState {
  mut pipes : Int
  mut last_pipe_ix : Int
  mut begin_text : Int
  mut backslash_escaped : Bool
}

///|
/// Returns end ix of setext_heading on success.
fn FirstPass::parse_setext_heading(
  self : FirstPass,
  ix : Int,
  node_ix : Int,
  has_trailing_content : Bool,
) -> Int? {
  let bytes = self.text
  guard scan_setext_heading(bytes.exact_view(start=ix)) is Some((n, level)) else {
    return None
  }
  let mut attrs : HeadingAttributes? = None

  if self.tree.cur() is Some(cur_ix) {
    let parent_ix = self.tree.peek_up().unwrap()
    let header_start = self.tree.nodes[parent_ix].item.start
    // Note that `item.end` might be zero at this point.
    let header_end = self.tree.nodes[cur_ix].item.end

    // extract the trailing attribute block
    let (content_end, attrs_) = self.extract_and_parse_heading_attribute_block(
      header_start, header_end,
    )
    attrs = attrs_

    // strip trailing whitespace
    let new_end = if has_trailing_content {
      content_end
    } else {
      let mut last_line_start = header_start
      if attrs is Some(_) {
        while true {
          let next_line_start = last_line_start +
            scan_nextline(bytes.exact_view(start=last_line_start))
          if next_line_start >= content_end {
            break
          }
          let line_start = LineStart::new(
            bytes.exact_view(start=next_line_start, end=content_end),
          )
          if line_start.scan_containers(self.tree, self.options) !=
            self.tree.spine_len() {
            break
          }
          last_line_start = next_line_start + line_start.bytes_scanned()
        }
      }
      let trailing_ws = scan_rev_while(
        bytes.exact_view(start=last_line_start, end=content_end),
        c => c.is_ascii_whitespace_no_nl(),
      )
      content_end - trailing_ws
    }

    if attrs is Some(_) {
      // remove trailing block attributes
      self.tree.truncate_siblings(new_end)
    }

    if self.tree.cur() is Some(cur_ix) {
      self.tree.nodes[cur_ix].item.end = new_end
    }
  }

  self.tree.nodes[node_ix].item.body = attrs.map_or(Heading(level, None), attrs => {
    Heading(level, Some(self.allocs.allocate_heading(attrs)))
  })

  Some(ix + n)
}

///|
/// Parse a line of input, appending text and items to tree.
/// Returns: index after line and an item representing the break.
fn FirstPass::parse_line(
  self : FirstPass,
  start : Int,
  end : Int?,
  mode : TableParseMode,
) -> (Int, Item?) {
  let bytes = self.text
  let bytes_len = bytes.length()
  let limit = end.unwrap_or(bytes_len)
  let mut state = LineState::{
    pipes: 0,
    last_pipe_ix: start,
    begin_text: start,
    backslash_escaped: false,
  }

  let mut final_ix = limit
  let mut brk : Item? = None

  let lut = special_bytes(self.options)
  let mut ix = start
  let mut done = false
  while ix < limit && !done {
    let byte = bytes.unsafe_get(ix)
    if lut[byte.to_int()] {
      let (action, new_state) = self.handle_special_byte(
        ix, byte, mode, limit, bytes_len, start, state,
      )
      state = new_state
      match action {
        ParseLineAction::Continue(skip) => ix += skip
        ParseLineAction::BreakWith(end_ix, item) => {
          final_ix = end_ix
          brk = item
          done = true
        }
      }
    }
    ix += 1
  }

  if brk is None {
    let trailing_whitespace = scan_rev_while(
      bytes.exact_view(start=state.begin_text, end=final_ix),
      c => c.is_ascii_whitespace_no_nl(),
    )
    // need to close text at eof
    self.tree.append_text(
      state.begin_text,
      final_ix - trailing_whitespace,
      state.backslash_escaped,
    )
  }
  (final_ix, brk)
}

///|
priv enum ParseLineAction {
  Continue(Int)
  BreakWith(Int, Item?)
}
