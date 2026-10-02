//! ATX headings, footnotes, reference definitions, and paragraph-interrupt
//! checks.

///|
/// Parse an ATX heading.
/// Returns index of start of next line.
fn FirstPass::parse_atx_heading(
  self : FirstPass,
  start : Int,
  atx_level : HeadingLevel,
) -> Int {
  let mut ix = start
  let heading_ix = self.tree.append(Item::{ start, end: 0, body: Root, })
  ix += atx_level.to_int()
  // next char is space or eol (guaranteed by scan_atx_heading)
  let bytes = self.text
  if scan_eol(bytes.exact_view(start=ix)) is Some(eol_bytes) {
    self.tree.nodes[heading_ix].item.end = ix + eol_bytes
    self.tree.nodes[heading_ix].item.body = Heading(atx_level, None)
    return ix + eol_bytes
  }
  // skip leading spaces
  let skip_spaces = scan_whitespace_no_nl(bytes.exact_view(start=ix))
  ix += skip_spaces

  // now handle the header text
  let header_start = ix
  ignore(self.tree.push()) // so that we can set the endpoint later

  // trim the trailing attribute block before parsing the entire line
  let (end, content_end, attrs) = if self.options.contains(
      enable_heading_attributes(),
    ) {
    // the start of the next line is the end of the header
    let header_end = header_start +
      scan_nextline(bytes.exact_view(start=header_start))
    let (content_end, attrs) = self.extract_and_parse_heading_attribute_block(
      header_start, header_end,
    )
    ignore(self.parse_line(ix, Some(content_end), Disabled))
    (header_end, content_end, attrs)
  } else {
    let (line_ix, line_brk) = self.parse_line(ix, None, Disabled)
    ix = line_ix
    // Backslash at end is actually hard line break
    if line_brk is Some(brk_item) {
      if brk_item.body is HardBreak(true) {
        self.tree.append_text(brk_item.start, brk_item.end, false)
      }
    }
    (ix, ix, None)
  }
  self.tree.nodes[heading_ix].item.end = end

  // remove trailing matter from header text
  let mut empty_text_node = false
  if self.tree.cur() is Some(cur_ix) {
    // remove closing of the ATX heading
    let header_text = bytes.exact_view(start=header_start, end=content_end)
    let mut limit = bytesview_iter_rev_position(
      header_text, not_is_newline_space,
    ).unwrap_or(0)
    let closer = bytesview_iter_rev_position(
      header_text.exact_view(start=0, end=limit),
      not_is_hash,
    ).unwrap_or(0)
    if closer == 0 {
      limit = closer
    } else {
      let spaces = scan_rev_while(header_text.exact_view(start=0, end=closer), b => {
        b == b' '
      })
      if spaces > 0 {
        limit = closer - spaces
      }
    }
    // if text is only spaces, then remove them
    self.tree.nodes[cur_ix].item.end = limit + header_start

    // limit = 0 when text is empty after removing spaces
    if limit == 0 {
      empty_text_node = true
    }
  }

  if empty_text_node {
    ignore(self.tree.remove_node())
  } else {
    ignore(self.tree.pop())
  }
  self.tree.nodes[heading_ix].item.body = attrs.map_or(
    Heading(atx_level, None),
    attrs => Heading(atx_level, Some(self.allocs.allocate_heading(attrs))),
  )

  end
}

///|
fn not_is_newline_space(b : Byte) -> Bool {
  !(b == b'\n' || b == b'\r' || b == b' ')
}

///|
fn not_is_hash(b : Byte) -> Bool {
  b != b'#'
}

///|
/// Returns the number of bytes scanned on success.
fn FirstPass::parse_footnote(self : FirstPass, start : Int) -> Int? {
  let bytes = self.text.exact_view(start~)
  guard bytes.has_prefix(b"[^".exact_view()) else { return None }
  let (i, label) = if self.options.options_has_gfm_footnotes() {
    // GitHub doesn't allow footnote definition labels to contain line breaks.
    guard scan_link_label_rest(
        self.text,
        start + 2,
        None,
        self.tree.is_in_table(),
      )
      is Some((n, label)) else {
      return None
    }
    (n, label)
  } else {
    guard self.parse_refdef_label(start + 2) is Some((n, label)) else {
      return None
    }
    (n, label)
  }
  let mut i = i
  guard !(self.options.options_has_gfm_footnotes() && label.contains("\n")) else {
    // GitHub doesn't allow footnote definition labels to contain line breaks,
    // even if they're escaped.
    return None
  }
  i += 2
  guard bytes.length() > i && bytes.unsafe_get(i) == b':' else { return None }
  i += 1
  self.finish_list(start)
  if self.tree.peek_up() is Some(node_ix) {
    let is_footnote = self.tree.nodes[node_ix].item.body
      is FootnoteDefinition(_)
    if is_footnote {
      // finish previous footnote if it's still open
      self.pop(start)
    }
  }
  if self.options.options_has_gfm_footnotes() {
    i += scan_whitespace_no_nl(bytes.exact_view(start=i))
  }
  self.allocs.footdefs[unicase_fold(label)] = { _use_count: 0, }
  ignore(
    self.tree.append(Item::{
      start,
      end: 0, // will get set later
      body: FootnoteDefinition(self.allocs.allocate_cow(label)),
    }),
  )
  ignore(self.tree.push())
  Some(i)
}

///|
/// Tries to parse a reference label, which can be interrupted by new blocks.
fn FirstPass::parse_refdef_label(
  self : FirstPass,
  start : Int,
) -> (Int, String)? {
  scan_link_label_rest(
    self.text,
    start,
    Some((bytes : BytesView) => {
      let line_start = LineStart::new(bytes)
      let tree_position = line_start.scan_containers(self.tree, self.options)
      let current_container = tree_position == self.tree.spine_len()
      guard !line_start.scan_space(4) else {
        return Some(line_start.bytes_scanned())
      }
      let bytes_scanned = line_start.bytes_scanned()
      let suffix = bytes.exact_view(start=bytes_scanned)
      let interrupt = self.scan_paragraph_interrupt(
          suffix, current_container, tree_position,
        ) ||
        (current_container && scan_setext_heading(suffix) is Some(_))
      guard !interrupt else { None }
      Some(bytes_scanned)
    }),
    self.tree.is_in_table(),
  )
}

///|
/// Returns number of bytes scanned, label and definition on success.
fn FirstPass::parse_refdef_total(
  self : FirstPass,
  start : Int,
) -> (Int, String, LinkDef)? {
  let bytes = self.text.exact_view(start~)
  guard bytes.length() > 0 && bytes.unsafe_get(0) == b'[' else { return None }
  guard self.parse_refdef_label(start + 1) is Some((i, label)) else {
    return None
  }
  let mut i = i
  i += 1
  guard bytes.length() > i && bytes.unsafe_get(i) == b':' else { return None }
  i += 1
  guard self.scan_refdef(start, start + i) is Some((bytecount, link_def)) else {
    return None
  }
  Some((bytecount + i, label, link_def))
}

///|
/// Returns number of bytes and number of newlines
fn FirstPass::scan_refdef_space(
  self : FirstPass,
  bytes : BytesView,
  i : Int,
) -> (Int, Int)? {
  let mut i = i
  let mut newlines = 0
  while true {
    let whitespaces = scan_whitespace_no_nl(bytes.exact_view(start=i))
    i += whitespaces
    guard scan_eol(bytes.exact_view(start=i)) is Some(eol_bytes) else { break }
    i += eol_bytes
    newlines += 1
    guard newlines <= 1 else { return None }
    let line_start = LineStart::new(bytes.exact_view(start=i))
    let tree_position = line_start.scan_containers(self.tree, self.options)
    let current_container = tree_position == self.tree.spine_len()
    if !line_start.scan_space(4) {
      let suffix = bytes.exact_view(start=i + line_start.bytes_scanned())
      let interrupt = self.scan_paragraph_interrupt(
          suffix, current_container, tree_position,
        ) ||
        scan_setext_heading(suffix) is Some(_)
      guard !interrupt else { return None }
    }
    i += line_start.bytes_scanned()
  }
  Some((i, newlines))
}

///|
/// returns (bytelength, title_str)
fn FirstPass::scan_refdef_title(
  self : FirstPass,
  text : BytesView,
) -> (Int, String)? {
  guard text.length() > 0 else { return None }
  let c = text.unsafe_get(0)
  let closing_delim = if c == b'\'' {
    b'\''
  } else if c == b'"' {
    b'"'
  } else if c == b'(' {
    b')'
  } else {
    return None
  }
  let mut bytecount = 1
  let mut linestart = 1

  let mut linebuf = StringBuilder()
  let mut has_linebuf = false

  while bytecount < text.length() {
    let c = text.unsafe_get(bytecount)
    guard !(closing_delim == b')' && c == b'(') else { return None }
    if c == b'\n' || c == b'\r' {
      if !has_linebuf {
        linebuf = StringBuilder()
        has_linebuf = true
      }
      linebuf.write_stringview(
        @utf8.decode_lossy(text.exact_view(start=linestart, end=bytecount)).exact_view(),
      )
      linebuf.write_string("\n") // normalize line breaks
      bytecount += 1
      if c == b'\r' &&
        bytecount < text.length() &&
        text.unsafe_get(bytecount) == b'\n' {
        bytecount += 1
      }
      let line_start = LineStart::new(text.exact_view(start=bytecount))
      let tree_position = line_start.scan_containers(self.tree, self.options)
      let current_container = tree_position == self.tree.spine_len()
      if !line_start.scan_space(4) {
        let suffix = text.exact_view(
          start=bytecount + line_start.bytes_scanned(),
        )
        let interrupt = self.scan_paragraph_interrupt(
            suffix, current_container, tree_position,
          ) ||
          scan_setext_heading(suffix) is Some(_)
        guard !interrupt else { return None }
      }
      line_start.scan_all_space()
      bytecount += line_start.bytes_scanned()
      linestart = bytecount
      guard scan_blank_line(text.exact_view(start=bytecount)) is None else {
        // blank line - not allowed
        return None
      }
    } else if c == b'\\' {
      bytecount += 1
      if bytecount < text.length() {
        let next = text.unsafe_get(bytecount)
        if next != b'\r' && next != b'\n' {
          bytecount += 1
        }
      }
    } else if c == closing_delim {
      let cow = if has_linebuf {
        linebuf.write_stringview(
          @utf8.decode_lossy(text.exact_view(start=linestart, end=bytecount)).exact_view(),
        )
        linebuf.to_string()
      } else {
        @utf8.decode_lossy(text.exact_view(start=linestart, end=bytecount))
      }
      return Some((bytecount + 1, cow))
    } else {
      bytecount += 1
    }
  }
  None
}

///|
/// Returns # of bytes and definition.
/// Assumes the label of the reference including colon has already been scanned.
fn FirstPass::scan_refdef(
  self : FirstPass,
  span_start : Int,
  start : Int,
) -> (Int, LinkDef)? {
  let bytes = self.text.exact_view(start=0)

  // whitespace between label and url (including up to one newline)
  guard self.scan_refdef_space(bytes, start) is Some((i, _newlines)) else {
    return None
  }
  let mut i = i

  // scan link dest
  guard scan_link_dest(self.text, i, 32)
    is Some((dest_length, dest_start, dest_end)) else {
    return None
  }
  guard dest_length != 0 else { return None }
  let dest = unescape(self.text, dest_start, dest_end, self.tree.is_in_table())
  i += dest_length

  // no title
  let backup = (
    i - start,
    LinkDef::{ dest, title: None, _span: (span_start, i), },
  )

  // scan whitespace between dest and label
  guard self.scan_refdef_space(bytes, i) is Some((new_i, newlines)) else {
    return Some(backup)
  }
  let newlines = if i == self.text.length() { newlines + 1 } else { newlines }
  guard !(new_i == i && newlines == 0) else { return None }
  guard newlines <= 1 else { return Some(backup) }
  let mut i = new_i

  // scan title
  if self.scan_refdef_title(bytes.exact_view(start=i))
    is Some((title_length, title_cow)) {
    i += title_length
    if scan_blank_line(bytes.exact_view(start=i)) is Some(_) {
      let title_bytes = @utf8.encode(title_cow)
      let backup_with_title = (
        i - start,
        LinkDef::{
          dest,
          title: Some(
            unescape(
              title_bytes,
              0,
              title_bytes.length(),
              self.tree.is_in_table(),
            ),
          ),
          _span: (span_start, i),
        },
      )
      return Some(backup_with_title)
    }
  }
  guard newlines <= 0 else { Some(backup) }
  None
}

///|
/// Checks whether we should break a paragraph on the given input.
fn FirstPass::scan_paragraph_interrupt(
  self : FirstPass,
  bytes : BytesView,
  current_container : Bool,
  tree_position : Int,
) -> Bool {
  guard !scan_paragraph_interrupt_no_table(
    bytes,
    current_container,
    self.options.contains(enable_footnotes()),
    self.options.contains(enable_definition_list()),
    self.tree,
    tree_position,
  ) else {
    return true
  }
  // Tables with a `|` on the header row are allowed to interrupt paragraphs.
  let not_table = !self.options.contains(enable_tables()) ||
    bytes.length() <= 0 ||
    bytes.unsafe_get(0) != b'|'
  guard !not_table else { return false }

  // Checking if something's a valid table or not requires looking at two lines.
  let mut pipes = 0
  let mut next_line_ix = 0
  let mut bsesc = false
  let mut last_pipe_ix = 0
  for i in 0..<bytes.length() {
    let byte = bytes.unsafe_get(i)
    if byte == b'\\' {
      bsesc = true
      continue
    }
    if byte == b'|' && !bsesc {
      pipes += 1
      last_pipe_ix = i
    }
    if byte == b'\r' || byte == b'\n' {
      next_line_ix = i + scan_eol(bytes.exact_view(start=i)).unwrap()
      break
    }
    bsesc = false
  }

  // scan_eol can't return 0, so this can't be zero
  guard next_line_ix != 0 else { return false }

  let line_start = LineStart::new(bytes.exact_view(start=next_line_ix))
  guard line_start.scan_containers(self.tree, self.options) ==
    self.tree.spine_len() else {
    return false
  }
  let table_head_ix = next_line_ix + line_start.bytes_scanned()
  let (table_head_bytes, alignment) = scan_table_head(
    bytes.exact_view(start=table_head_ix),
  )

  guard table_head_bytes != 0 else { return false }

  let header_count = count_header_cols(bytes, pipes, 0, last_pipe_ix)

  alignment.length() == header_count
}

///|
/// Extracts and parses a heading attribute block if exists.
fn FirstPass::extract_and_parse_heading_attribute_block(
  self : FirstPass,
  header_start : Int,
  header_end : Int,
) -> (Int, HeadingAttributes?) {
  guard self.options.contains(enable_heading_attributes()) else {
    return (header_end, None)
  }

  // extract the trailing attribute block
  let header_bytes = self.text.exact_view(start=header_start, end=header_end)
  let (content_len, attr_block_range_rel) = extract_attribute_block_content_from_header_text(
    header_bytes,
  )
  let content_end = header_start + content_len
  let attrs = attr_block_range_rel.bind(range => {
    let (r_start, r_end) = range
    parse_inside_attribute_block(
      @utf8.decode_lossy(
        self.text.exact_view(
          start=header_start + r_start,
          end=header_start + r_end,
        ),
      ),
    )
  })
  (content_end, attrs)
}

///|
/// Checks whether we should break a paragraph on the given input.
fn scan_paragraph_interrupt_no_table(
  bytes : BytesView,
  current_container : Bool,
  has_footnote : Bool,
  definition_list : Bool,
  tree : Tree[Item],
  tree_position : Int,
) -> Bool {
  guard scan_eol(bytes) is None else { return true }
  guard scan_hrule(bytes) is Err(_) else { return true }
  guard scan_atx_heading(bytes) is None else { return true }
  guard scan_code_fence(bytes) is None else { return true }
  guard !scan_interrupting_container_extensions_fence(bytes) else {
    return true
  }
  guard scan_blockquote_start(bytes) is None else { return true }
  let list_interrupt = scan_listitem(bytes).map_or(false, marker => {
    let (ix, delim, index, _) = marker
    !current_container ||
    tree.is_in_table() ||
    (
      (delim == b'*' || delim == b'-' || delim == b'+' || index == 1) &&
      scan_blank_line(bytes.exact_view(start=ix)) is None
    )
  })
  guard !list_interrupt else { return true }
  let html_interrupt = bytes.length() > 0 &&
    bytes.unsafe_get(0) == b'<' &&
    (
      get_html_end_tag(bytes.exact_view(start=1)) is Some(_) ||
      starts_html_block_type_6(bytes.exact_view(start=1))
    )
  guard !html_interrupt else { return true }
  let deflist_current = current_container &&
    tree
    .peek_up()
    .map_or(false, cur => {
      tree.nodes[cur].item.body
      is (Paragraph | TightParagraph | MaybeDefinitionListTitle)
    })
  let deflist_spine_item = if tree_position < tree.spine_len() {
    let spine = tree.walk_spine()
    tree.nodes[spine[tree_position]].item.body is DefinitionListDefinition(_)
  } else {
    false
  }
  let deflist_interrupt = definition_list &&
    (deflist_current || deflist_spine_item) &&
    bytes.length() > 0 &&
    bytes.unsafe_get(0) == b':'
  guard !deflist_interrupt else { return true }
  let has_foot_prefix = has_footnote && bytes.has_prefix(b"[^".exact_view())
  let foot_label_ok = if has_foot_prefix {
    scan_link_label_rest(
      @utf8.encode(@utf8.decode_lossy(bytes.exact_view(start=2))),
      0,
      None,
      tree.is_in_table(),
    ).map_or(false, label => {
      let (len, _) = label
      bytes.length() > 2 + len && bytes.unsafe_get(2 + len) == b':'
    })
  } else {
    false
  }
  guard !foot_label_ok else { return true }
  false
}

///|
/// Assumes `text_bytes` is preceded by `<`.
fn get_html_end_tag(text_bytes : BytesView) -> String? {
  let begin_tags = [b"pre", b"style", b"script", b"textarea"]
  let end_tags = ["</pre>", "</style>", "</script>", "</textarea>"]
  for idx in 0..<begin_tags.length() {
    let beg_tag = begin_tags[idx]
    let tag_len = beg_tag.length()

    if text_bytes.length() < tag_len {
      // begin tags are increasing in size
      break
    }

    guard eq_ignore_ascii_case(
      text_bytes.exact_view(start=0, end=tag_len),
      beg_tag.exact_view(),
    ) else {
      continue
    }

    // Must either be the end of the line...
    guard text_bytes.length() != tag_len else { return Some(end_tags[idx]) }

    // ...or be followed by whitespace, newline, or '>'.
    let s = text_bytes.unsafe_get(tag_len)
    guard !(s.to_char().is_ascii_whitespace() || s == b'>') else {
      return Some(end_tags[idx])
    }
  }

  let st_begin_tags = [b"!--", b"?", b"![CDATA["]
  let st_end_tags = ["-->", "?>", "]]>"]
  for idx in 0..<st_begin_tags.length() {
    guard !text_bytes.has_prefix(st_begin_tags[idx].exact_view()) else {
      return Some(st_end_tags[idx])
    }
  }

  let is_decl = text_bytes.length() > 1 &&
    text_bytes.unsafe_get(0) == b'!' &&
    text_bytes.unsafe_get(1).to_char().is_ascii_alphabetic()
  guard !is_decl else { Some(">") }
  None
}

///|
fn surgerize_tight_list(tree : Tree[Item], list_ix : Int) -> Unit {
  let mut list_item = tree.nodes[list_ix].child
  while true {
    guard list_item is Some(listitem_ix) else { break }
    let mut node_ix = tree.nodes[listitem_ix].child
    while true {
      guard node_ix is Some(node) else { break }
      if tree.nodes[node].item.body is Paragraph {
        tree.nodes[node].item.body = TightParagraph
      }
      node_ix = tree.nodes[node].next
    }
    list_item = tree.nodes[listitem_ix].next
  }
}

///|
fn fixup_end_of_definition_list(tree : Tree[Item], list_ix : Int) -> Unit {
  let mut list_item = tree.nodes[list_ix].child
  let mut previous_list_item : Int? = None
  while true {
    guard list_item is Some(listitem_ix) else { break }
    match tree.nodes[listitem_ix].item.body {
      DefinitionListTitle | DefinitionListDefinition(_) => {
        previous_list_item = Some(listitem_ix)
        list_item = tree.nodes[listitem_ix].next
      }
      MaybeDefinitionListTitle => {
        tree.nodes[listitem_ix].item.body = Paragraph
        break
      }
      _ => break
    }
  }
  if previous_list_item is Some(prev) {
    tree.truncate_to_parent(prev)
  }
}
