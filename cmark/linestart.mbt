///|
/// Analysis of the beginning of a line, including indentation and container
/// markers.
priv struct LineStart {
  mut bytes : BytesView
  mut ix : Int

  // The index in `bytes` after the last tab we scanned; initially zero.
  mut tab_start : Int

  // In contexts where spaces help to define block structure, tabs
  // behave as if they were replaced by spaces with a tab stop of 4
  // characters. If we have scanned past a tab character but not consumed all
  // the horizontal width it contributed, this is the number of spaces
  // logically remaining, before the character at `ix`.
  mut spaces_remaining : Int

  // no thematic breaks can occur before this offset.
  mut min_hrule_offset : Int
}

///|
fn LineStart::new(bytes : BytesView) -> LineStart {
  { bytes, ix: 0, tab_start: 0, spaces_remaining: 0, min_hrule_offset: 0, }
}

///|
fn LineStart::clone(self : LineStart) -> LineStart {
  {
    bytes: self.bytes,
    ix: self.ix,
    tab_start: self.tab_start,
    spaces_remaining: self.spaces_remaining,
    min_hrule_offset: self.min_hrule_offset,
  }
}

///|
fn LineStart::restore(self : LineStart, save : LineStart) -> Unit {
  self.bytes = save.bytes
  self.ix = save.ix
  self.tab_start = save.tab_start
  self.spaces_remaining = save.spaces_remaining
  self.min_hrule_offset = save.min_hrule_offset
}

///|
/// Try to scan a number of spaces.
/// Returns true if all spaces were consumed.
fn LineStart::scan_space(self : LineStart, n_space : Int) -> Bool {
  self.scan_space_inner(n_space) == 0
}

///|
/// Scan a number of spaces up to a maximum.
/// Returns number of spaces scanned.
fn LineStart::scan_space_upto(self : LineStart, n_space : Int) -> Int {
  n_space - self.scan_space_inner(n_space)
}

///|
/// Returns unused remainder of spaces.
fn LineStart::scan_space_inner(self : LineStart, n_space : Int) -> Int {
  let mut n_space = n_space
  // Consume any common prefix between the number of spaces we
  // want and the number of unscanned tab-introduced spaces.
  let n_from_remaining = self.spaces_remaining.min(n_space)
  self.spaces_remaining -= n_from_remaining
  n_space -= n_from_remaining

  while n_space > 0 && self.ix < self.bytes.length() {
    let b = self.bytes.unsafe_get(self.ix)
    if b == b' ' {
      self.ix += 1
      n_space -= 1
    } else if b == b'\t' {
      let spaces = 4 - (self.ix - self.tab_start) % 4
      self.ix += 1
      self.tab_start = self.ix
      let n = spaces.min(n_space)
      n_space -= n

      // Record the unscanned portion of the tab.
      self.spaces_remaining = spaces - n
    } else {
      break
    }
  }
  n_space
}

///|
/// Scan all available ASCII whitespace (not including eol).
fn LineStart::scan_all_space(self : LineStart) -> Unit {
  self.spaces_remaining = 0
  while self.ix < self.bytes.length() {
    let b = self.bytes.unsafe_get(self.ix)
    if b == b' ' || b == b'\t' {
      self.ix += 1
    } else {
      break
    }
  }
}

///|
/// Determine whether we're at end of line (includes end of file).
fn LineStart::is_at_eol(self : LineStart) -> Bool {
  if self.ix < self.bytes.length() {
    let c = self.bytes.unsafe_get(self.ix)
    c == b'\r' || c == b'\n'
  } else {
    true
  }
}

///|
fn LineStart::scan_ch(self : LineStart, c : Byte) -> Bool {
  if self.ix < self.bytes.length() && self.bytes.unsafe_get(self.ix) == c {
    self.ix += 1
    true
  } else {
    false
  }
}

///|
fn LineStart::scan_case_insensitive(self : LineStart, tag : BytesView) -> Bool {
  guard self.bytes.length() - self.ix >= tag.length() else { return false }
  let prefix = self.bytes.exact_view(start=self.ix, end=self.ix + tag.length())
  let ok = eq_ignore_ascii_case(prefix, tag)
  if ok {
    self.ix += tag.length()
  }
  ok
}

///|
fn eq_ignore_ascii_case(a : BytesView, b : BytesView) -> Bool {
  guard a.length() == b.length() else { return false }
  let mut i = 0
  while i < a.length() {
    let x = a.unsafe_get(i).to_int() | 0x20
    let y = b.unsafe_get(i).to_int() | 0x20
    guard x == y else { return false }
    i += 1
  }
  true
}

///|
fn LineStart::scan_blockquote_tag(self : LineStart) -> BlockQuoteKind? {
  let saved_ix = self.ix
  guard self.scan_ch(b'[') && self.scan_ch(b'!') else {
    self.ix = saved_ix
    return None
  }
  let kind = self.scan_blockquote_kind()
  guard kind is Some(kind) else {
    self.ix = saved_ix
    return None
  }
  guard self.scan_ch(b']') else {
    self.ix = saved_ix
    return None
  }
  guard scan_blank_line(self.bytes.exact_view(start=self.ix)) is Some(nl) else {
    self.ix = saved_ix
    return None
  }
  self.ix += nl
  Some(kind)
}

///|
/// Scans one of the blockquote tag names; the caller restores `ix` on
/// failure.
fn LineStart::scan_blockquote_kind(self : LineStart) -> BlockQuoteKind? {
  if self.scan_case_insensitive(b"note".exact_view()) {
    Some(Note)
  } else if self.scan_case_insensitive(b"tip".exact_view()) {
    Some(Tip)
  } else if self.scan_case_insensitive(b"important".exact_view()) {
    Some(Important)
  } else if self.scan_case_insensitive(b"warning".exact_view()) {
    Some(Warning)
  } else if self.scan_case_insensitive(b"caution".exact_view()) {
    Some(Caution)
  } else {
    None
  }
}

///|
fn LineStart::scan_blockquote_marker(self : LineStart) -> Bool {
  if self.scan_ch(b'>') {
    ignore(self.scan_space(1))
    true
  } else {
    false
  }
}

///|
fn LineStart::scan_closing_container_extensions_fence(
  self : LineStart,
  length : Int,
) -> Bool {
  let fence_length = scan_while_max(
    self.bytes.exact_view(start=self.ix),
    c => c == b':',
    255,
  )
  if fence_length >= length {
    self.ix = self.ix + fence_length
    true
  } else {
    false
  }
}

///|
/// Scan a definition marker.
fn LineStart::scan_definition_list_definition_marker_with_indent(
  self : LineStart,
  indent : Int,
) -> Int? {
  let save = self.clone()
  if self.scan_ch(b':') {
    let save = self.clone()
    if self.scan_space(5) {
      self.restore(save)
      Some(indent + 1 + self.scan_space_upto(1))
    } else {
      self.restore(save)
      Some(indent + 1 + self.scan_space_upto(5))
    }
  } else {
    self.restore(save)
    None
  }
}

///|
/// Scan a list marker.
fn LineStart::scan_list_marker_with_indent(
  self : LineStart,
  indent : Int,
) -> (Byte, Int64, Int)? {
  let save = self.clone()
  if self.ix < self.bytes.length() {
    let c = self.bytes.unsafe_get(self.ix)
    if c == b'-' || c == b'+' || c == b'*' {
      if self.ix >= self.min_hrule_offset {
        // there could be an hrule here
        match scan_hrule(self.bytes.exact_view(start=self.ix)) {
          Ok(_) => {
            self.restore(save)
            return None
          }
          Err(min_offset) => self.min_hrule_offset = min_offset
        }
      }
      self.ix += 1
      guard !(self.scan_space(1) || self.is_at_eol()) else {
        return self.finish_list_marker(c, 0, indent + 2)
      }
    } else if c.to_char().is_ascii_digit() {
      let start_ix = self.ix
      let mut ix = self.ix + 1
      let mut val = Int64::from_int(c.to_int() - 0x30)
      while ix < self.bytes.length() && ix - start_ix < 10 {
        let c = self.bytes.unsafe_get(ix)
        ix += 1
        if c.to_char().is_ascii_digit() {
          val = val * 10 + Int64::from_int(c.to_int() - 0x30)
        } else if c == b')' || c == b'.' {
          self.ix = ix
          guard !(self.scan_space(1) || self.is_at_eol()) else {
            return self.finish_list_marker(c, val, indent + 1 + ix - start_ix)
          }
          break
        } else {
          break
        }
      }
    }
  }
  self.restore(save)
  None
}

///|
fn LineStart::finish_list_marker(
  self : LineStart,
  c : Byte,
  start : Int64,
  indent : Int,
) -> (Byte, Int64, Int)? {
  let mut indent = indent
  let save = self.clone()

  // skip the rest of the line if it's blank
  guard scan_blank_line(self.bytes.exact_view(start=self.ix)) is None else {
    return Some((c, start, indent))
  }

  let post_indent = self.scan_space_upto(4)
  if post_indent < 4 {
    indent += post_indent
  } else {
    self.restore(save)
  }
  Some((c, start, indent))
}

///|
/// Returns Some(is_checked) when a task list marker was found.
fn LineStart::scan_task_list_marker(self : LineStart) -> Bool? {
  let save = self.clone()
  ignore(self.scan_space_upto(3))

  if !self.scan_ch(b'[') {
    self.restore(save)
    return None
  }
  let is_checked = if self.ix < self.bytes.length() {
    let c = self.bytes.unsafe_get(self.ix)
    if c.is_ascii_whitespace_no_nl() {
      self.ix += 1
      false
    } else if c == b'x' || c == b'X' {
      self.ix += 1
      true
    } else {
      self.restore(save)
      return None
    }
  } else {
    self.restore(save)
    return None
  }
  if !self.scan_ch(b']') {
    self.restore(save)
    return None
  }
  let after = if self.ix < self.bytes.length() {
    self.bytes.unsafe_get(self.ix).to_char().is_ascii_whitespace()
  } else {
    true
  }
  if !after {
    self.restore(save)
    return None
  }
  Some(is_checked)
}

///|
fn LineStart::bytes_scanned(self : LineStart) -> Int {
  self.ix
}

///|
fn LineStart::remaining_space(self : LineStart) -> Int {
  self.spaces_remaining
}

///|
/// Returns number of containers scanned.
fn LineStart::scan_containers(
  self : LineStart,
  tree : Tree[Item],
  options : Options,
) -> Int {
  let mut i = 0
  let spine = tree.walk_spine()
  for idx in 0..<spine.length() {
    let node_ix = spine[idx]
    let body = tree.nodes[node_ix].item.body
    match body {
      BlockQuote(_) => {
        let save = self.clone()
        ignore(self.scan_space(3))
        if !self.scan_blockquote_marker() {
          self.restore(save)
          break
        }
      }
      ListItem(indent) => {
        let save = self.clone()
        if !self.scan_space(indent) && !self.is_at_eol() {
          self.restore(save)
          break
        }
      }
      DefinitionListDefinition(indent) => {
        let save = self.clone()
        if !self.scan_space(indent) && !self.is_at_eol() {
          self.restore(save)
          break
        }
      }
      FootnoteDefinition(_) if options.options_has_gfm_footnotes() => {
        let save = self.clone()
        if !self.scan_space(4) && !self.is_at_eol() {
          self.restore(save)
          break
        }
      }
      _ => ()
    }
    i += 1
  }
  i
}
