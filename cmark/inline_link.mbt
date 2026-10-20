//! Inline resolution pass 2: link and wikilink scanning, math and code
//! spans, and reference lookup.

///|
/// Returns next byte index, url and title.
fn Parser::scan_inline_link(
  self : Parser,
  underlying : BytesView,
  ix : Int,
  node : Int?,
) -> (Int, String, String)? {
  let mut ix = ix
  guard underlying.length() > ix && underlying.unsafe_get(ix) == b'(' else {
    return None
  }
  ix += 1

  let sep1 = self.scan_separator(underlying, ix)
  ix += sep1

  guard scan_link_dest(underlying, ix, LINK_MAX_NESTED_PARENS)
    is Some((dest_length, dest_start, dest_end)) else {
    return None
  }
  let dest = unescape(self.text, dest_start, dest_end, self.tree.is_in_table())
  ix += dest_length

  let title_sep = self.scan_separator(underlying, ix)
  ix += title_sep

  // scan title
  let title = {
    guard self.scan_link_title(underlying, ix, node) is Some((bytes_scanned, t)) else {
      ""
    }
    guard title_sep != 0 else { return None }
    ix += bytes_scanned
    t
  }

  // scan any remaining whitespace
  ix += self.scan_separator(underlying, ix)
  guard underlying.length() > ix && underlying.unsafe_get(ix) == b')' else {
    return None
  }
  ix += 1
  Some((ix, dest, title))
}

///|
/// Scans whitespace (including a possible line break + container prefixes).
fn Parser::scan_separator(
  self : Parser,
  underlying : BytesView,
  ix0 : Int,
) -> Int {
  let start = ix0
  let mut i = ix0
  i += scan_while(underlying.exact_view(start=i), c => {
    c.is_ascii_whitespace_no_nl()
  })
  if scan_eol(underlying.exact_view(start=i)) is Some(bl) {
    i += bl
    i += skip_container_prefixes(
      self.tree,
      underlying.exact_view(start=i),
      self.options,
    )
  }
  i += scan_while(underlying.exact_view(start=i), c => {
    c.is_ascii_whitespace_no_nl()
  })
  i - start
}

// returns (bytes scanned, title cow)

///|
fn Parser::scan_link_title(
  self : Parser,
  text : BytesView,
  start_ix : Int,
  node : Int?,
) -> (Int, String)? {
  let bytes = text
  guard bytes.length() > start_ix else { return None }
  let open = bytes.unsafe_get(start_ix)
  guard open == b'\'' || open == b'"' || open == b'(' else { return None }
  let close = if open == b'(' { b')' } else { open }

  let title = StringBuilder()
  let mut mark = start_ix + 1
  let mut i = start_ix + 1

  while i < bytes.length() {
    let c = bytes.unsafe_get(i)

    if c == close {
      let cow = if mark == 1 {
        replace_nuls(@utf8.decode_lossy(text.exact_view(start=mark, end=i)))
      } else {
        title.write_stringview(
          @utf8.decode_lossy(text.exact_view(start=mark, end=i)).exact_view(),
        )
        replace_nuls(title.to_string())
      }
      return Some((i - start_ix + 1, cow))
    }
    guard c != open else { return None }

    if c == b'\n' || c == b'\r' {
      if scan_nodes_to_ix(self.tree, node, i + 1) is Some(node_ix) &&
        self.tree.nodes[node_ix].item.start > i {
        title.write_stringview(
          @utf8.decode_lossy(text.exact_view(start=mark, end=i)).exact_view(),
        )
        title.write_string("\n")
        i = self.tree.nodes[node_ix].item.start
        mark = i
        continue
      }
    }
    if c == b'&' {
      if scan_entity(bytes.exact_view(start=i)) is (n, Some(value)) {
        title.write_stringview(
          @utf8.decode_lossy(text.exact_view(start=mark, end=i)).exact_view(),
        )
        title.write_string(value)
        i += n
        mark = i
        continue
      }
    }
    let is_table_pipe_escape = self.tree.is_in_table() &&
      c == b'\\' &&
      i + 2 < bytes.length() &&
      bytes.unsafe_get(i + 1) == b'\\' &&
      bytes.unsafe_get(i + 2) == b'|'
    if is_table_pipe_escape {
      // this runs if there are an even number of pipes in a table
      title.write_stringview(
        @utf8.decode_lossy(text.exact_view(start=mark, end=i)).exact_view(),
      )
      i += 2
      mark = i
    }
    let is_backslash_escape = c == b'\\' &&
      i + 1 < bytes.length() &&
      is_ascii_punctuation(bytes.unsafe_get(i + 1).to_int())
    if is_backslash_escape {
      title.write_stringview(
        @utf8.decode_lossy(text.exact_view(start=mark, end=i)).exact_view(),
      )
      i += 1
      mark = i
    }

    i += 1
  }

  None
}

///|
fn Parser::make_math_span(self : Parser, open : Int, close : Int) -> Unit {
  let mut close = close
  let start_is_display = self.tree.nodes[open].next.map_or(false, next_ix => {
    next_ix != close && self.tree.nodes[next_ix].item.body is MaybeMath(_, _, _)
  })
  let end_is_display = self.tree.nodes[close].next.map_or(false, next_ix => {
    self.tree.nodes[next_ix].item.body is MaybeMath(_, _, _)
  })
  let is_display = start_is_display && end_is_display
  if is_display {
    // This unwrap() can't panic, because if the next variable were None, end_is_display would be None
    let next = self.tree.nodes[close].next.unwrap()
    close = next
    self.tree.nodes[open].next = Some(close)
    self.tree.nodes[open].item.end += 1
    self.tree.nodes[close].item.start -= 1
  } else {
    if self.tree.nodes[open].item.end == self.tree.nodes[close].item.start {
      // inline math spans cannot be empty
      self.tree.nodes[open].item.body = Text(false)
      return
    }
    self.tree.nodes[open].next = Some(close)
  }
  let span_start = self.tree.nodes[open].item.end
  let span_end = self.tree.nodes[close].item.start

  let spanned_text = self.text.exact_view(start=span_start, end=span_end)
  let spanned_bytes = spanned_text
  let buf2 : StringBuilder = StringBuilder()
  let mut has_buf = false

  let mut start_ix = 0
  let mut ix = 0
  while ix < spanned_bytes.length() {
    let c = spanned_bytes.unsafe_get(ix)
    if c == b'\r' || c == b'\n' {
      ix += 1
      if !has_buf {
        has_buf = true
      }
      buf2.write_stringview(
        @utf8.decode_lossy(spanned_text.exact_view(start=start_ix, end=ix)).exact_view(),
      )
      ix += skip_container_prefixes(
        self.tree,
        spanned_bytes.exact_view(start=ix),
        self.options,
      )
      start_ix = ix
    } else {
      let is_escaped_pipe = c == b'\\' &&
        spanned_bytes.length() > ix + 1 &&
        spanned_bytes.unsafe_get(ix + 1) == b'|' &&
        self.tree.is_in_table()
      if is_escaped_pipe {
        if !has_buf {
          has_buf = true
        }
        buf2.write_stringview(
          @utf8.decode_lossy(spanned_text.exact_view(start=start_ix, end=ix)).exact_view(),
        )
        buf2.write_string("|")
        ix += 2
        start_ix = ix
      } else {
        ix += 1
      }
    }
  }

  let cow = if has_buf {
    buf2.write_stringview(
      @utf8.decode_lossy(
        spanned_text.exact_view(start=start_ix, end=spanned_bytes.length()),
      ).exact_view(),
    )
    replace_nuls(buf2.to_string())
  } else {
    replace_nuls(
      @utf8.decode_lossy(
        spanned_text.exact_view(start=0, end=spanned_bytes.length()),
      ),
    )
  }

  self.tree.nodes[open].item.body = Math(
    self.allocs.allocate_cow(cow),
    is_display,
  )
  self.tree.nodes[open].item.end = self.tree.nodes[close].item.end
  self.tree.nodes[open].next = self.tree.nodes[close].next
}

///|
/// Make a code span.
fn Parser::make_code_span(
  self : Parser,
  open : Int,
  close : Int,
  preceding_backslash : Bool,
) -> Unit {
  let span_start = self.tree.nodes[open].item.end
  let span_end = self.tree.nodes[close].item.start
  let buf = StringBuilder()
  let mut has_buf = false

  let spanned_text = self.text.exact_view(start=span_start, end=span_end)
  let spanned_bytes = spanned_text
  let mut start_ix = 0
  let mut ix = 0
  while ix < spanned_bytes.length() {
    let c = spanned_bytes.unsafe_get(ix)
    if c == b'\r' || c == b'\n' {
      if !has_buf {
        has_buf = true
      }
      buf.write_stringview(
        @utf8.decode_lossy(spanned_text.exact_view(start=start_ix, end=ix)).exact_view(),
      )
      buf.write_string(" ")
      ix += 1
      ix += skip_container_prefixes(
        self.tree,
        spanned_bytes.exact_view(start=ix),
        self.options,
      )
      start_ix = ix
    } else {
      let is_escaped_pipe = c == b'\\' &&
        spanned_bytes.length() > ix + 1 &&
        spanned_bytes.unsafe_get(ix + 1) == b'|' &&
        self.tree.is_in_table()
      if is_escaped_pipe {
        if !has_buf {
          has_buf = true
        }
        buf.write_stringview(
          @utf8.decode_lossy(spanned_text.exact_view(start=start_ix, end=ix)).exact_view(),
        )
        buf.write_string("|")
        ix += 2
        start_ix = ix
      } else {
        ix += 1
      }
    }
  }

  let (opening, closing, all_spaces) = {
    let s = if has_buf {
      buf.write_stringview(
        @utf8.decode_lossy(
          spanned_text.exact_view(start=start_ix, end=spanned_bytes.length()),
        ).exact_view(),
      )
      buf.to_string()
    } else {
      @utf8.decode_lossy(
        spanned_text.exact_view(start=0, end=spanned_bytes.length()),
      )
    }
    let sb = @utf8.encode(s)
    (
      sb.length() > 0 && sb.unsafe_get(0) == b' ',
      sb.length() > 0 && sb.unsafe_get(sb.length() - 1) == b' ',
      s.split(" ").all(v => v.is_empty()),
    )
  }

  let cow = if !all_spaces && opening && closing {
    let sb = @utf8.encode(buf.to_string())
    if has_buf {
      let inner = if sb.length() > 0 {
        @utf8.decode_lossy(sb.exact_view(start=1, end=sb.length() - 1))
      } else {
        ""
      }
      replace_nuls(inner)
    } else {
      let slen = spanned_bytes.length()
      let inner = if slen > 1 {
        @utf8.decode_lossy(spanned_text.exact_view(start=1, end=slen - 1))
      } else {
        ""
      }
      replace_nuls(inner)
    }
  } else if has_buf {
    replace_nuls(buf.to_string())
  } else {
    replace_nuls(
      @utf8.decode_lossy(
        spanned_text.exact_view(start=0, end=spanned_bytes.length()),
      ),
    )
  }

  if preceding_backslash {
    self.tree.nodes[open].item.body = Text(true)
    self.tree.nodes[open].item.end = self.tree.nodes[open].item.start + 1
    self.tree.nodes[open].next = Some(close)
    self.tree.nodes[close].item.body = Code(self.allocs.allocate_cow(cow))
    self.tree.nodes[close].item.start = self.tree.nodes[open].item.start + 1
  } else {
    self.tree.nodes[open].item.body = Code(self.allocs.allocate_cow(cow))
    self.tree.nodes[open].item.end = self.tree.nodes[close].item.end
    self.tree.nodes[open].next = self.tree.nodes[close].next
  }
}

///|
/// On success, returns a buffer containing the inline html and byte offset.
fn Parser::scan_inline_html(
  self : Parser,
  bytes : BytesView,
  ix : Int,
) -> (Array[Byte], Int)? {
  guard bytes.length() > ix else { return None }
  let c = bytes.unsafe_get(ix)
  if c == b'!' {
    scan_inline_html_comment(bytes, ix + 1, self.html_scan_guard).map(n => {
      ([], n)
    })
  } else if c == b'?' {
    scan_inline_html_processing(bytes, ix + 1, self.html_scan_guard).map(n => {
      ([], n)
    })
  } else {
    scan_html_block_inner(
      // Subtract 1 to include the < character
      bytes.exact_view(start=ix - 1),
      Some((bytes : BytesView) => {
        skip_container_prefixes(self.tree, bytes, self.options)
      }),
    ).map(result => {
      let (span, i) = result
      (span, i + ix - 1)
    })
  }
}

///|
fn Parser::disable_all_links(self : Parser) -> Unit {
  self.link_stack.disable_all_links()
  self.wikilink_stack.disable_all_links()
}

///|
/// Use a link label to fetch a type, url, and title.
fn Parser::fetch_link_type_url_title(
  self : Parser,
  link_label : String,
  _span : (Int, Int),
  link_type : LinkType,
) -> (LinkType, String, String)? {
  guard self.link_ref_expansion_limit != 0 else { return None }

  let found = self.allocs.refdefs
    .get(link_label)
    .map(matching_def => {
      (link_type, matching_def.dest, matching_def.title.unwrap_or(""))
    })

  guard found is Some(found) else { return None }
  let (link_type, url, title) = found

  // Limit expansion from link references.
  self.link_ref_expansion_limit = (0).max(
    self.link_ref_expansion_limit - (url.length() + title.length()),
  )

  Some((link_type, url, title))
}

///|
/// Skips forward within a block to a node which spans (ends inclusive) the given
/// index into the source.
fn skip_container_prefixes(
  tree : Tree[Item],
  bytes : BytesView,
  options : Options,
) -> Int {
  let line_start = LineStart::new(bytes)
  ignore(line_start.scan_containers(tree, options))
  line_start.bytes_scanned()
}

///|
/// Handles a wikilink.
fn Parser::handle_wikilink(
  self : Parser,
  block_text : BytesView,
  cur_ix : Int,
  prev : Int?,
) -> Int? {
  guard self.tree.nodes[cur_ix].next is Some(next_ix) else { return None }
  guard self.wikilink_stack.pop() is Some(tos) else { return None }
  guard !(tos.ty is Disabled) else { return None }
  // fetches the beginning of the wikilink body
  let body_node = self.tree.nodes[tos.node].next.bind(a => {
    self.tree.nodes[a].next
  })
  guard body_node is Some(body_node) else { return None }
  let start_ix = self.tree.nodes[body_node].item.start
  let end_ix = self.tree.nodes[cur_ix].item.start
  // bail early in case the link is malformed
  guard end_ix > start_ix else { return None }
  let wikilink = match
    scan_wikilink_pipe(block_text, start_ix, end_ix - start_ix) {
    Some((rest, pipe_pos)) => {
      let wikitext = @utf8.decode_lossy(
        block_text.exact_view(start=start_ix, end=pipe_pos),
      )
      // bail early if the wikiname would be empty
      guard !wikitext.is_empty() else { return None }
      // [[WikiName|rest]]
      if rest >= end_ix {
        // Empty display text: the `|` is immediately followed by `]]`.
        let body_node = self.tree.create_node(Item::{
          start: rest,
          end: rest,
          body: Text(false),
        })
        Some((true, body_node, wikitext))
      } else {
        scan_nodes_to_ix(self.tree, Some(body_node), rest).bind(body_node => {
          // break node so passes can actually format the display text
          self.tree.nodes[body_node].item.start = rest
          Some((true, body_node, wikitext))
        })
      }
    }
    None => {
      let wikitext = @utf8.decode_lossy(
        block_text.exact_view(start=start_ix, end=end_ix),
      )
      // bail early if the wikiname would be empty
      guard !wikitext.is_empty() else { return None }
      let body_node = self.tree.create_node(Item::{
        start: start_ix,
        end: end_ix,
        body: Text(false),
      })
      if wikitext.contains("\u0000") {
        self.tree.nodes[body_node].item.body = SynthesizeText(
          self.allocs.allocate_cow(replace_nuls(wikitext)),
        )
      }
      Some((false, body_node, wikitext))
    }
  }

  if wikilink is Some((has_pothole, body_node, wikiname)) {
    let link_ix = self.allocs.allocate_link(
      WikiLink(has_pothole),
      replace_nuls(wikiname),
      "",
      "",
    )
    if prev is Some(prev_ix) {
      self.tree.nodes[prev_ix].next = None
    }
    self.tree.nodes[tos.node].item.body = if tos.ty is Image {
      Image(link_ix)
    } else {
      Link(link_ix)
    }
    self.tree.nodes[tos.node].child = Some(body_node)
    self.tree.nodes[tos.node].next = self.tree.nodes[next_ix].next
    self.tree.nodes[tos.node].item.end = end_ix + 2
    self.disable_all_links()
    return Some(tos.node)
  }

  None
}
