//! Inline resolution pass 3: emphasis matching, hard breaks, and the
//! delimiter stacks.

///|
priv struct InlineEl {
  /// offset of tree node
  start : Int32
  /// number of delimiters available for matching
  count : Int32
  c : Byte
}

///|
struct InlineStack {
  stack : Array[InlineEl]
  // Lower bounds for matching indices in the stack.
  lower_bounds : Array[Int32]
}

///|
// Single- and double-tilde runs need separate bounds so matching one
// cannot hide an unmatched opener of the other length.
fn extension_delim_index(c : Byte, count : Int32) -> Int32 {
  if c == b'~' {
    count - 1
  } else {
    2
  }
}

///|
fn inline_stack_new() -> InlineStack {
  { stack: [], lower_bounds: Array::make(3, 0), }
}

///|
fn InlineStack::pop_all(self : InlineStack, tree : Tree[Item]) -> Unit {
  for el in self.stack {
    for i in 0..<el.count {
      tree.nodes[el.start + i].item.body = Text
    }
  }
  self.stack.clear()
  for i in 0..<self.lower_bounds.length() {
    self.lower_bounds[i] = 0
  }
}

///|
fn InlineStack::truncate(self : InlineStack, new_bound : Int32) -> Unit {
  self.stack.truncate(new_bound)
  for i in 0..<self.lower_bounds.length() {
    if self.lower_bounds[i] > new_bound {
      self.lower_bounds[i] = new_bound
    }
  }
}

///|
fn InlineStack::find_match(
  self : InlineStack,
  tree : Tree[Item],
  c : Byte,
  count : Int32,
) -> InlineEl? {
  let is_emphasis = c == b'*' || c == b'_'
  let lowerbound = if is_emphasis {
    0
  } else {
    self.lower_bounds[extension_delim_index(c, count)]
  }
  // search from the end
  let mut i = self.stack.length() - 1
  while i >= lowerbound {
    let el = self.stack[i]
    if el.c == c && el.count == count {
      let matching_el = self.stack[i]
      // truncate the stack after the match, converting popped delims to text
      for j in (i + 1)..<self.stack.length() {
        let el = self.stack[j]
        for k in 0..<el.count {
          tree.nodes[el.start + k].item.body = Text
        }
      }
      self.truncate(i)
      return Some(matching_el)
    }
    // An extension cannot close across an open emphasis boundary.
    if el.c == b'*' || el.c == b'_' {
      break
    }
    i -= 1
  }

  if !is_emphasis {
    self.lower_bounds[extension_delim_index(c, count)] = self.stack.length()
  }
  None
}

///|
fn InlineStack::push(self : InlineStack, el : InlineEl) -> Unit {
  if el.c != b'*' && el.c != b'_' {
    let ix = extension_delim_index(el.c, el.count)
    self.lower_bounds[ix] = self.lower_bounds[ix].min(self.stack.length())
  }
  self.stack.push(el)
}

///|
/// Tracks tree indices of code span delimiters of each length.
struct CodeDelims {
  inner : @hashmap.HashMap[Int32, @deque.Deque[Int32]]
  mut seen_first : Bool
}

///|
fn code_delims_new() -> CodeDelims {
  { inner: @hashmap.HashMap::HashMap([]), seen_first: false, }
}

///|
fn CodeDelims::insert(self : CodeDelims, count : Int32, ix : Int32) -> Unit {
  if self.seen_first {
    if self.inner.get(count) is Some(q) {
      q.push_back(ix)
    } else {
      let q : @deque.Deque[Int32] = @deque.Deque([], capacity=0)
      q.push_back(ix)
      self.inner.set(count, q)
    }
  } else {
    // Skip the first insert, since that delimiter will always
    // be an opener and not a closer.
    self.seen_first = true
  }
}

///|
fn CodeDelims::is_populated(self : CodeDelims) -> Bool {
  !self.inner.is_empty()
}

///|
fn CodeDelims::find(
  self : CodeDelims,
  open_ix : Int32,
  count : Int32,
) -> Int32? {
  while true {
    guard self.inner.get(count) is Some(q) else { return None }
    guard q.pop_front() is Some(ix) else { return None }
    if ix > open_ix {
      return Some(ix)
    }
  }
  None
}

///|
fn CodeDelims::clear(self : CodeDelims) -> Unit {
  self.inner.clear()
  self.seen_first = false
}

///|
/// Tracks brace contexts and delimiter length for math delimiters.
struct MathDelims {
  inner : @hashmap.HashMap[Int32, @deque.Deque[(Int32, Bool)]]
}

///|
fn math_delims_new() -> MathDelims {
  { inner: @hashmap.HashMap::HashMap([]), }
}

///|
fn MathDelims::insert(
  self : MathDelims,
  delim_is_display : Bool,
  brace_context : Int32,
  ix : Int32,
) -> Unit {
  if self.inner.get(brace_context) is Some(q) {
    q.push_back((ix, delim_is_display))
  } else {
    let q : @deque.Deque[(Int32, Bool)] = @deque.Deque([], capacity=0)
    q.push_back((ix, delim_is_display))
    self.inner.set(brace_context, q)
  }
}

///|
fn MathDelims::is_populated(self : MathDelims) -> Bool {
  !self.inner.is_empty()
}

///|
fn MathDelims::find(
  self : MathDelims,
  tree : Tree[Item],
  open_ix : Int32,
  is_display : Bool,
  brace_context : Int32,
) -> Int32? {
  while true {
    guard self.inner.get(brace_context) is Some(q) else { return None }
    guard q.pop_front() is Some((ix, delim_is_display)) else { return None }
    if ix <= open_ix || (is_display && tree.nodes[open_ix].next == Some(ix)) {
      continue
    }
    let nonempty = tree.nodes[open_ix].item.end != tree.nodes[ix].item.start
    guard !((!is_display && nonempty) || (is_display && delim_is_display)) else {
      return Some(ix)
    }
    // if we can't use it, leave it in the queue as a tombstone
    q.push_front((ix, delim_is_display))
    break
  }
  None
}

///|
fn MathDelims::clear(self : MathDelims) -> Unit {
  self.inner.clear()
}

///|
/// Applies the inner "work from the inside out" loop of emphasis matching.
/// Returns `true` if the opener matched successfully (caller finishes the
/// outer iteration), or `false` if the opener should be turned into text and
/// the outer search retried.
fn Parser::apply_emphasis_inner(
  self : Parser,
  el : InlineEl,
  start : Int32,
  end : Int32,
  match_count : Int32,
  prev : Int32?,
) -> Bool {
  let mut start = start
  let mut end = end
  let c = el.c
  while start > el.start + el.count - match_count {
    let inc = if start > el.start + el.count - match_count + 1 { 2 } else { 1 }
    let ty = if c == b'~' {
      if self.options.contains(enable_strikethrough()) {
        Some(ItemBody::Strikethrough)
      } else {
        None
      }
    } else if c == b'=' {
      if inc == 2 && self.options.contains(enable_highlight()) {
        Some(ItemBody::Highlight)
      } else {
        None
      }
    } else if inc == 2 {
      Some(ItemBody::Strong)
    } else {
      Some(ItemBody::Emphasis)
    }

    guard ty is Some(ty) else {
      self.tree.nodes[el.start].item.body = Text
      return false
    }
    // have a match!
    let root = start - inc
    end = end + inc
    self.tree.nodes[root].item.body = ty
    self.tree.nodes[root].item.end = self.tree.nodes[end].item.end
    self.tree.nodes[root].child = Some(start)
    self.tree.nodes[root].next = None
    if prev is Some(prev_ix) {
      self.tree.nodes[prev_ix].next = None
    }
    start = root
  }
  true
}

///|
fn Parser::handle_emphasis_and_hard_break(
  self : Parser,
) -> Unit raise SyntaxError {
  let mut prev : Int32? = None
  let mut cur = self.tree.cur()
  let mut emphasis_open : InlineEl? = None
  let mut inside_emphasis = false
  for ix in self.tree.spine {
    if self.tree.nodes[ix].item.body is (Emphasis | Strong) {
      inside_emphasis = true
      break
    }
  }

  let mut single_quote_open : Int32? = None
  let mut double_quote_open = false

  while true {
    guard cur is Some(cur_ix) else { break }
    match self.tree.nodes[cur_ix].item.body {
      MaybeEmphasis(count, can_open, can_close) => {
        let offset = self.tree.nodes[cur_ix].item.start
        let c = self.text.unsafe_get(offset)
        let is_emphasis = c == b'*' || c == b'_'
        let can_close = if is_emphasis {
          guard count <= 2 else {
            raise SyntaxError::InvalidEmphasisRun(offset, offset + count)
          }
          guard !inside_emphasis else {
            raise SyntaxError::NestedEmphasis(offset, offset + count)
          }
          if emphasis_open is Some(open) {
            guard open.c == c && open.count == count else {
              raise SyntaxError::MismatchedEmphasis(offset, offset + count)
            }
            true
          } else {
            false
          }
        } else {
          can_close
        }
        if can_close {
          if self.inline_stack.find_match(self.tree, c, count) is Some(el) {
            if self.apply_emphasis_inner(
                el,
                el.start + count,
                cur_ix - 1,
                count,
                prev,
              ) {
              prev = Some(el.start)
              cur = self.tree.nodes[cur_ix + count - 1].next
              self.tree.nodes[el.start].next = cur
              if is_emphasis {
                emphasis_open = None
              }
              continue
            }
          }
        }
        if can_open {
          let el = InlineEl::{ start: cur_ix, count, c, }
          self.inline_stack.push(el)
          if is_emphasis {
            emphasis_open = Some(el)
          }
        } else {
          for i in 0..<count {
            self.tree.nodes[cur_ix + i].item.body = Text
          }
        }
        let prev_ix = cur_ix + count - 1
        prev = Some(prev_ix)
        cur = self.tree.nodes[prev_ix].next
      }
      MaybeSmartQuote(c, can_open, can_close) => {
        let body = if c == b'\'' {
          if single_quote_open is Some(_) && can_close {
            let open_ix = single_quote_open.unwrap()
            self.tree.nodes[open_ix].item.body = SynthesizeChar('‘')
            single_quote_open = None
            SynthesizeChar('’')
          } else {
            if can_open {
              single_quote_open = Some(cur_ix)
            }
            SynthesizeChar('’')
          }
          // double quote
        } else if can_close && double_quote_open {
          double_quote_open = false
          SynthesizeChar('”')
        } else {
          if can_open && !double_quote_open {
            double_quote_open = true
          }
          SynthesizeChar('“')
        }
        self.tree.nodes[cur_ix].item.body = body
        prev = cur
        cur = self.tree.nodes[cur_ix].next
      }
      HardBreak(true) => {
        if self.tree.nodes[cur_ix].next is None {
          self.tree.nodes[cur_ix].item.body = SynthesizeChar('\\')
        }
        prev = cur
        cur = self.tree.nodes[cur_ix].next
      }
      _ => {
        prev = cur
        cur = self.tree.nodes[cur_ix].next
      }
    }
  }
  if emphasis_open is Some(open) {
    let offset = self.tree.nodes[open.start].item.start
    raise SyntaxError::UnclosedEmphasis(offset, offset + open.count)
  }
  self.inline_stack.pop_all(self.tree)
}
