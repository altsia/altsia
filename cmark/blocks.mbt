//! The first pass resolves all block structure, generating an AST.
//! Within a block, items are in a linear chain with potential inline markup
//! identified.

// Each level of brace nesting adds another entry to a hash table.

///|
const MATH_BRACE_CONTEXT_MAX_NESTING : Int = 25

///|
/// State for the first parsing pass.
priv struct FirstPass {
  text : Bytes
  tree : Tree[Item]
  mut begin_list_item : Int?
  mut last_line_blank : Bool
  allocs : Allocations
  options : Options
  // Math environment brace nesting.
  brace_context_stack : Array[Int]
  mut brace_context_next : Int
}

///|
fn run_first_pass(text : Bytes, options : Options) -> (Tree[Item], Allocations) {
  // This is a very naive heuristic for the number of nodes we'll need.
  let start_capacity = (128).max(text.length() / 32)
  let first_pass = FirstPass::{
    text,
    tree: tree_with_capacity(start_capacity),
    begin_list_item: None,
    last_line_blank: false,
    allocs: allocations_new(),
    options,
    brace_context_stack: [],
    brace_context_next: 0,
  }
  first_pass.run()
}

///|
fn FirstPass::run(self : FirstPass) -> (Tree[Item], Allocations) {
  let mut ix = 0
  while ix < self.text.length() {
    ix = self.parse_block(ix)
  }
  while self.tree.spine_len() > 0 {
    self.pop(ix)
  }
  (self.tree, self.allocs)
}

///|
/// Returns offset after block.
fn FirstPass::parse_block(self : FirstPass, start_ix : Int) -> Int {
  let mut start_ix = start_ix
  let bytes = self.text
  let mut line_start = LineStart::new(bytes.exact_view(start=start_ix))

  // math spans and their braces are tracked only within a single block
  self.brace_context_stack.clear()
  self.brace_context_next = 0

  let i = line_start.scan_containers(self.tree, self.options)
  for _ in i..<self.tree.spine_len() {
    self.pop(start_ix)
  }

  if self.options.contains(enable_old_footnotes()) {
    // finish footnote if it's still open and was preceded by blank line
    guard self.tree.peek_up() is Some(node_ix) else { () }
    let is_footnote = self.tree.nodes[node_ix].item.body
      is FootnoteDefinition(_)
    if is_footnote && self.last_line_blank {
      self.pop(start_ix)
    }
  }

  // Process new containers
  while true {
    let save = line_start.clone()
    let outer_indent = line_start.scan_space_upto(4)
    guard outer_indent < 4 else {
      line_start.restore(save)
      break
    }
    if self.options.contains(enable_footnotes()) {
      // Footnote definitions
      let container_start = start_ix + line_start.bytes_scanned()
      guard self.parse_footnote(container_start) is Some(bytecount) else { () }
      start_ix = container_start + bytecount
      if self.options.contains(enable_old_footnotes()) {
        // gfm footnotes need indented, but old footnotes don't
        if scan_blank_line(bytes.exact_view(start=start_ix)) is Some(n) {
          start_ix += n
        }
      }
      line_start = LineStart::new(bytes.exact_view(start=start_ix))
      continue
    }
    let container_start = start_ix + line_start.bytes_scanned()
    match line_start.scan_list_marker_with_indent(outer_indent) {
      Some((ch, index, indent)) => {
        let after_marker_index = start_ix + line_start.bytes_scanned()
        self.continue_list(container_start - outer_indent, ch, index)
        ignore(
          self.tree.append(Item::{
            start: container_start - outer_indent,
            end: after_marker_index, // will get updated later if item not empty
            body: ListItem(indent),
          }),
        )
        ignore(self.tree.push())
        if scan_blank_line(bytes.exact_view(start=after_marker_index)) is Some(n) {
          self.begin_list_item = Some(after_marker_index + n)
          return after_marker_index + n
        }
        if self.options.contains(enable_tasklists()) {
          guard line_start.scan_task_list_marker() is Some(is_checked) else {
            ()
          }
          let task_list_marker = Item::{
            start: after_marker_index,
            end: start_ix + line_start.bytes_scanned(),
            body: TaskListMarker(is_checked),
          }
          match scan_blank_line(bytes.exact_view(start=task_list_marker.end)) {
            Some(n) => {
              ignore(self.tree.append(task_list_marker))
              self.begin_list_item = Some(task_list_marker.end + n)
              return task_list_marker.end + n
            }
            None => {
              line_start.scan_all_space()
              let ix = start_ix + line_start.bytes_scanned()
              return self.parse_paragraph(ix, Some(task_list_marker))
            }
          }
        }
      }
      None => {
        // Definition list?
        if self.options.contains(enable_definition_list()) {
          guard self.tree.cur() is Some(cur) else { () }
          let child = self.tree.nodes[cur].child
          let cur_item = self.tree.nodes[cur].item
          let is_para = cur_item.body
            is (Paragraph
            | TightParagraph
            | MaybeDefinitionListTitle
            | DefinitionListDefinition(_))
          guard is_para else { () }
          guard line_start.scan_definition_list_definition_marker_with_indent(
              outer_indent,
            )
            is Some(indent2) else {
            ()
          }
          match self.tree.nodes[cur].item.body {
            Paragraph | TightParagraph => {
              self.tree.nodes[cur].item.body = DefinitionList(true)
              let list_idx = self.tree.cur().unwrap()
              let title_idx = self.tree.create_node(Item::{
                start: cur_item.start,
                end: cur_item.end, // will get updated later if item not empty
                body: DefinitionListTitle,
              })
              self.tree.nodes[title_idx].child = child
              self.tree.nodes[list_idx].child = Some(title_idx)
              ignore(self.tree.push())
            }
            MaybeDefinitionListTitle =>
              self.tree.nodes[cur].item.body = DefinitionListTitle
            _ => ()
          }
          let after_marker_index = start_ix + line_start.bytes_scanned()
          ignore(
            self.tree.append(Item::{
              start: container_start - outer_indent,
              end: after_marker_index, // will get updated later
              body: DefinitionListDefinition(indent2),
            }),
          )
          if self.tree.peek_up() is Some(up) {
            match self.tree.nodes[up].item.body {
              DefinitionList(_) =>
                if self.last_line_blank {
                  self.tree.nodes[up].item.body = DefinitionList(false)
                  self.last_line_blank = false
                }
              _ => ()
            }
          }
          ignore(self.tree.push())
          if scan_blank_line(bytes.exact_view(start=after_marker_index)) is Some(n) {
            self.begin_list_item = Some(after_marker_index + n)
            return after_marker_index + n
          }
          continue
        }
        if line_start.scan_blockquote_marker() {
          let kind = if self.options.contains(enable_gfm()) {
            line_start.scan_blockquote_tag()
          } else {
            None
          }
          self.finish_list(start_ix)
          ignore(
            self.tree.append(Item::{
              start: container_start,
              end: 0,
              body: BlockQuote(kind),
            }),
          )
          ignore(self.tree.push())
          if kind is Some(_) {
            // blockquote tag leaves us at the end of the line
            let ix = start_ix + line_start.bytes_scanned()
            let lazy_line_start = LineStart::new(bytes.exact_view(start=ix))
            let tree_position = lazy_line_start.scan_containers(
              self.tree,
              self.options,
            )
            let current_container = tree_position == self.tree.spine_len()
            let interrupt = !lazy_line_start.scan_space(4) &&
              self.scan_paragraph_interrupt(
                bytes.exact_view(start=ix + lazy_line_start.bytes_scanned()),
                current_container,
                tree_position,
              )
            guard !interrupt else { return ix }
            // blockquote tags act as if they were nested in a paragraph
            line_start = lazy_line_start
            line_start.scan_all_space()
            start_ix = ix
            break
          }
          continue
        } else {
          let is_container_fence = self.options.contains(
              enable_container_extensions(),
            ) &&
            scan_ch_repeat(
              bytes.exact_view(start=start_ix + line_start.bytes_scanned()),
              b':',
            ) >
            2
          if is_container_fence {
            let fence_length = scan_while_max(
              bytes.exact_view(start=start_ix + line_start.bytes_scanned()),
              c => c == b':',
              255,
            )
            guard self.tree.spine_len() <= 255 else { break }
            let excess_colons = scan_while(
              bytes.exact_view(
                start=start_ix + line_start.bytes_scanned() + fence_length,
              ),
              c => c == b':',
            )
            let mut kind_start = start_ix +
              line_start.bytes_scanned() +
              fence_length +
              excess_colons
            kind_start += scan_whitespace_no_nl(bytes.exact_view(start=kind_start))
            let kind_length = scan_while(bytes.exact_view(start=kind_start), c => {
              c.is_ascii_alphanumeric() ||
              c == b'_' ||
              c == b'-' ||
              c == b':' ||
              c == b'.'
            })
            guard kind_length != 0 else { break }
            let kind = unescape(
              self.text,
              kind_start,
              kind_start + kind_length,
              self.tree.is_in_table(),
            )
            let mut summary_start = kind_start + kind_length
            summary_start += scan_whitespace_no_nl(
              bytes.exact_view(start=summary_start),
            )
            let line_end = summary_start +
              scan_nextline(bytes.exact_view(start=summary_start))
            let summary_end = line_end -
              scan_rev_while(bytes.exact_view(start=summary_start, end=line_end), c => {
                c.to_char().is_ascii_whitespace()
              })
            let is_spoiler = eq_ignore_ascii_case(
              @utf8.encode(kind).exact_view(),
              b"spoiler".exact_view(),
            )
            if is_spoiler {
              let summary = unescape(
                self.text,
                summary_start,
                summary_end,
                self.tree.is_in_table(),
              )
              let summary_cow_ix = self.allocs.allocate_cow(summary)
              ignore(
                self.tree.append(Item::{
                  start: container_start,
                  end: 0,
                  body: Container(fence_length, Spoiler, summary_cow_ix),
                }),
              )
            } else {
              let kind_cow_ix = self.allocs.allocate_cow(kind)
              ignore(
                self.tree.append(Item::{
                  start: container_start,
                  end: 0,
                  body: Container(fence_length, Default, kind_cow_ix),
                }),
              )
            }
            ignore(self.tree.push())
            return summary_end + 1
          } else {
            line_start.restore(save)
            break
          }
        }
      }
    }
  }

  if self.options.contains(enable_container_extensions()) {
    let spine = self.tree.walk_spine()
    for idx in 0..<spine.length() {
      let node_ix = spine[spine.length() - 1 - idx]
      match self.tree.nodes[node_ix].item.body {
        Container(length, _, _) =>
          if line_start.scan_closing_container_extensions_fence(length) {
            for _ in 0..<(idx + 1) {
              self.pop(start_ix)
            }
            break
          }
        _ => break
      }
    }
  }
  let ix = start_ix + line_start.bytes_scanned()

  if scan_blank_line(bytes.exact_view(start=ix)) is Some(n) {
    match self.tree.peek_up() {
      Some(node_ix) =>
        match self.tree.nodes[node_ix].item.body {
          Container(_, _, _) => ()
          BlockQuote(_) => ()
          ListItem(_) | DefinitionListDefinition(_) if self.begin_list_item
            is Some(_) => {
            self.last_line_blank = true
            // This is a blank list item.
            self.tree.nodes[node_ix].item.body = ListItem(0)
          }
          _ => self.last_line_blank = true
        }
      None => self.last_line_blank = true
    }
    return ix + n
  }

  // Save `remaining_space` here to avoid needing to backtrack `line_start` for HTML blocks
  let remaining_space = line_start.remaining_space()

  let indent = line_start.scan_space_upto(4)
  guard indent != 4 else {
    self.finish_list(start_ix)
    return self.parse_indented_code_block(
      start_ix + line_start.bytes_scanned(),
      line_start.remaining_space(),
    )
  }

  let ix = start_ix + line_start.bytes_scanned()

  // metadata blocks cannot be indented
  if indent == 0 {
    if scan_metadata_block(
        bytes.exact_view(start=ix),
        self.options.contains(enable_yaml_style_metadata_blocks()),
        self.options.contains(enable_pluses_delimited_metadata_blocks()),
      )
      is Some((_n, metadata_block_ch)) {
      self.finish_list(start_ix)
      return self.parse_metadata_block(ix, metadata_block_ch)
    }
  }

  // HTML Blocks
  if bytes.length() > ix && bytes.unsafe_get(ix) == b'<' {
    // Types 1-5 are all detected by one function
    if get_html_end_tag(bytes.exact_view(start=ix + 1)) is Some(html_end_tag) {
      self.finish_list(start_ix)
      return self.parse_html_block_type_1_to_5(
        ix, html_end_tag, remaining_space, indent,
      )
    }

    // Detect type 6
    guard !starts_html_block_type_6(bytes.exact_view(start=ix + 1)) else {
      self.finish_list(start_ix)
      return self.parse_html_block_type_6_or_7(ix, remaining_space, indent)
    }

    // Detect type 7
    guard scan_html_type_7(bytes.exact_view(start=ix)) is None else {
      self.finish_list(start_ix)
      return self.parse_html_block_type_6_or_7(ix, remaining_space, indent)
    }
  }

  if scan_hrule(bytes.exact_view(start=ix)) is Ok(n) {
    self.finish_list(start_ix)
    return self.parse_hrule(n, ix)
  }

  if scan_atx_heading(bytes.exact_view(start=ix)) is Some(atx_size) {
    self.finish_list(start_ix)
    return self.parse_atx_heading(ix, atx_size)
  }

  if scan_code_fence(bytes.exact_view(start=ix)) is Some((n, fence_ch)) {
    self.finish_list(start_ix)
    return self.parse_fenced_code_block(ix, indent, fence_ch, n)
  }

  // parse refdef
  while true {
    guard self.parse_refdef_total(start_ix + line_start.bytes_scanned())
      is Some((bytecount, label, link_def)) else {
      break
    }
    let folded_label = unicase_fold(label)
    if !self.allocs.refdefs.contains(folded_label) {
      self.allocs.refdefs[folded_label] = link_def
    }
    let container_start = start_ix + line_start.bytes_scanned()
    let mut ix = container_start + bytecount
    // Refdefs act as if they were contained within a paragraph
    if scan_blank_line(bytes.exact_view(start=ix)) is Some(nl) {
      ix += nl
    } else {
      self.finish_list(start_ix)
      return ix
    }
    match self.scan_next_line_or_lazy_continuation(bytes.exact_view(start=ix)) {
      Some(lazy_line_start) => {
        line_start = lazy_line_start
        start_ix = ix
      }
      None => {
        self.finish_list(start_ix)
        return ix
      }
    }
  }

  let ix = start_ix + line_start.bytes_scanned()

  self.parse_paragraph(ix, None)
}
