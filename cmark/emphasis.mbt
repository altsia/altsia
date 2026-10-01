//! Inline resolution pass 3: emphasis matching, hard breaks, and the
//! delimiter stacks.

///|
priv struct InlineEl {
  /// offset of tree node
  start : Int
  /// number of delimiters available for matching
  count : Int
  /// length of the run that these delimiters came from
  run_length : Int
  /// b'*', b'_', or b'~'
  c : Byte
  /// can both open and close
  both : Bool
}

///|
struct InlineStack {
  stack : Array[InlineEl]
  // Lower bounds for matching indices in the stack.
  lower_bounds : Array[Int]
}

// indices into the lower bounds array

///|
const UNDERSCORE_NOT_BOTH : Int = 0

///|
const ASTERISK_NOT_BOTH : Int = 1

///|
const ASTERISK_BASE : Int = 2

///|
const TILDES : Int = 5

///|
const UNDERSCORE_BASE : Int = 6

///|
const CIRCUMFLEXES : Int = 9

///|
const EQUALS : Int = 10

///|
fn has_valid_delim_rule(
  run_length : Int,
  el_run_length : Int,
  both : Bool,
  el_both : Bool,
) -> Bool {
  (!both && !el_both) ||
  (run_length + el_run_length) % 3 != 0 ||
  run_length % 3 == 0
}

///|
fn inline_stack_new() -> InlineStack {
  { stack: [], lower_bounds: Array::make(11, 0), }
}

///|
fn InlineStack::pop_all(self : InlineStack, tree : Tree[Item]) -> Unit {
  for el in self.stack {
    for i in 0..<el.count {
      tree.nodes[el.start + i].item.body = Text(false)
    }
  }
  self.stack.clear()
  for i in 0..<11 {
    self.lower_bounds[i] = 0
  }
}

///|
fn InlineStack::get_lowerbound(
  self : InlineStack,
  c : Byte,
  count : Int,
  both : Bool,
) -> Int {
  if c == b'_' {
    let mod3_lower = self.lower_bounds[UNDERSCORE_BASE + count % 3]
    if both {
      mod3_lower
    } else {
      mod3_lower.min(self.lower_bounds[UNDERSCORE_NOT_BOTH])
    }
  } else if c == b'*' {
    let mod3_lower = self.lower_bounds[ASTERISK_BASE + count % 3]
    if both {
      mod3_lower
    } else {
      mod3_lower.min(self.lower_bounds[ASTERISK_NOT_BOTH])
    }
  } else if c == b'^' {
    self.lower_bounds[CIRCUMFLEXES]
  } else if c == b'=' {
    self.lower_bounds[EQUALS]
  } else {
    self.lower_bounds[TILDES]
  }
}

///|
fn InlineStack::set_lowerbound(
  self : InlineStack,
  c : Byte,
  count : Int,
  both : Bool,
  new_bound : Int,
) -> Unit {
  if c == b'_' {
    if both {
      self.lower_bounds[UNDERSCORE_BASE + count % 3] = new_bound
    } else {
      self.lower_bounds[UNDERSCORE_NOT_BOTH] = new_bound
    }
  } else if c == b'*' {
    self.lower_bounds[ASTERISK_BASE + count % 3] = new_bound
    if !both {
      self.lower_bounds[ASTERISK_NOT_BOTH] = new_bound
    }
  } else if c == b'^' {
    self.lower_bounds[CIRCUMFLEXES] = new_bound
  } else if c == b'=' {
    self.lower_bounds[EQUALS] = new_bound
  } else {
    self.lower_bounds[TILDES] = new_bound
  }
}

///|
fn InlineStack::truncate(self : InlineStack, new_bound : Int) -> Unit {
  self.stack.truncate(new_bound)
  for i in 0..<11 {
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
  run_length : Int,
  both : Bool,
) -> InlineEl? {
  let lowerbound = self.stack
    .length()
    .min(self.get_lowerbound(c, run_length, both))
  // search from the end
  let mut i = self.stack.length() - 1
  while i >= lowerbound {
    let el = self.stack[i]
    let run_matches = if c == b'~' || c == b'^' || c == b'=' {
      run_length == el.run_length
    } else {
      true
    }
    let type_matches = el.c == c &&
      has_valid_delim_rule(run_length, el.run_length, both, el.both)
    if run_matches && type_matches {
      let matching_el = self.stack[i]
      // truncate the stack after the match, converting popped delims to text
      for j in (i + 1)..<self.stack.length() {
        let el = self.stack[j]
        for k in 0..<el.count {
          tree.nodes[el.start + k].item.body = Text(false)
        }
      }
      self.truncate(i)
      return Some(matching_el)
    }
    i -= 1
  }

  self.set_lowerbound(c, run_length, both, self.stack.length())
  None
}

///|
fn InlineStack::trim_lower_bound(self : InlineStack, ix : Int) -> Unit {
  self.lower_bounds[ix] = self.lower_bounds[ix].min(self.stack.length())
}

///|
fn InlineStack::push(self : InlineStack, el : InlineEl) -> Unit {
  if el.c == b'~' {
    self.trim_lower_bound(TILDES)
  } else if el.c == b'^' {
    self.trim_lower_bound(CIRCUMFLEXES)
  } else if el.c == b'=' {
    self.trim_lower_bound(EQUALS)
  }
  self.stack.push(el)
}

///|
/// Tracks tree indices of code span delimiters of each length.
struct CodeDelims {
  inner : @hashmap.HashMap[Int, @deque.Deque[Int]]
  mut seen_first : Bool
}

///|
fn code_delims_new() -> CodeDelims {
  { inner: @hashmap.HashMap::HashMap([]), seen_first: false, }
}

///|
fn CodeDelims::insert(self : CodeDelims, count : Int, ix : Int) -> Unit {
  if self.seen_first {
    if self.inner.get(count) is Some(q) {
      q.push_back(ix)
    } else {
      let q : @deque.Deque[Int] = @deque.Deque([], capacity=0)
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
fn CodeDelims::find(self : CodeDelims, open_ix : Int, count : Int) -> Int? {
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
  inner : @hashmap.HashMap[Int, @deque.Deque[(Int, Bool, Bool)]]
}

///|
fn math_delims_new() -> MathDelims {
  { inner: @hashmap.HashMap::HashMap([]), }
}

///|
fn MathDelims::insert(
  self : MathDelims,
  delim_is_display : Bool,
  brace_context : Int,
  ix : Int,
  can_close : Bool,
) -> Unit {
  if self.inner.get(brace_context) is Some(q) {
    q.push_back((ix, can_close, delim_is_display))
  } else {
    let q : @deque.Deque[(Int, Bool, Bool)] = @deque.Deque([], capacity=0)
    q.push_back((ix, can_close, delim_is_display))
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
  open_ix : Int,
  is_display : Bool,
  brace_context : Int,
) -> Int? {
  while true {
    guard self.inner.get(brace_context) is Some(q) else { return None }
    guard q.pop_front() is Some((ix, can_close, delim_is_display)) else {
      return None
    }
    if ix <= open_ix || (is_display && tree.nodes[open_ix].next == Some(ix)) {
      continue
    }
    let can_close = can_close &&
      tree.nodes[open_ix].item.end != tree.nodes[ix].item.start
    guard !((!is_display && can_close) || (is_display && delim_is_display)) else {
      return Some(ix)
    }
    // if we can't use it, leave it in the queue as a tombstone
    q.push_front((ix, can_close, delim_is_display))
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
  start : Int,
  end : Int,
  match_count : Int,
  prev : Int?,
) -> Bool {
  let mut start = start
  let mut end = end
  let c = el.c
  while start > el.start + el.count - match_count {
    let inc = if start > el.start + el.count - match_count + 1 { 2 } else { 1 }
    let ty = if c == b'~' {
      if inc == 2 {
        if self.options.contains(enable_strikethrough()) {
          Some(ItemBody::Strikethrough)
        } else {
          None
        }
      } else if self.options.contains(enable_subscript()) {
        Some(ItemBody::Subscript)
      } else if self.options.contains(enable_strikethrough()) {
        Some(ItemBody::Strikethrough)
      } else {
        None
      }
    } else if c == b'^' {
      if self.options.contains(enable_superscript()) {
        Some(ItemBody::Superscript)
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
      self.tree.nodes[el.start].item.body = Text(false)
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
fn Parser::handle_emphasis_and_hard_break(self : Parser) -> Unit {
  let mut prev : Int? = None
  let mut cur = self.tree.cur()

  let mut single_quote_open : Int? = None
  let mut double_quote_open = false

  while true {
    guard cur is Some(cur_ix) else { break }
    let mut cur_ix = cur_ix
    match self.tree.nodes[cur_ix].item.body {
      MaybeEmphasis(count, can_open, can_close) => {
        let mut count = count
        let run_length = count
        let c = self.text.unsafe_get(self.tree.nodes[cur_ix].item.start)
        let both = can_open && can_close
        if can_close {
          // try to find a matching opener; retry while a match succeeds
          while true {
            guard self.inline_stack.find_match(self.tree, c, run_length, both)
              is Some(el) else {
              break
            }
            let match_count = count.min(el.count)
            // start, end are tree node indices
            let end = cur_ix - 1
            let start = el.start + el.count

            let ok = self.apply_emphasis_inner(
              el, start, end, match_count, prev,
            )
            guard ok else { continue }

            // set next for top most emph level
            let prev_ix = el.start + el.count - match_count
            prev = Some(prev_ix)
            cur = self.tree.nodes[cur_ix + match_count - 1].next
            self.tree.nodes[prev_ix].next = cur

            if el.count > match_count {
              self.inline_stack.push(InlineEl::{
                start: el.start,
                count: el.count - match_count,
                run_length: el.run_length,
                c: el.c,
                both: el.both,
              })
            }
            count -= match_count
            if count > 0 {
              cur_ix = cur.unwrap()
              // retry to find another match
              continue
            }
            break
          }
        }
        if count > 0 {
          if can_open {
            self.inline_stack.push(InlineEl::{
              start: cur_ix,
              run_length,
              count,
              c,
              both,
            })
          } else {
            for i in 0..<count {
              self.tree.nodes[cur_ix + i].item.body = Text(false)
            }
          }
          let prev_ix = cur_ix + count - 1
          prev = Some(prev_ix)
          cur = self.tree.nodes[prev_ix].next
        }
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
  self.inline_stack.pop_all(self.tree)
}
