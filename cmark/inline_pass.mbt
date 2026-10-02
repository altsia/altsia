//! Inline resolution pass 1: HTML, code spans, links, math, and the stacks
//! and link-label scanners they use.

///|
/// Handle inline markup.
fn Parser::handle_inline(self : Parser) -> Unit {
  self.handle_inline_pass1()
  self.handle_emphasis_and_hard_break()
}

///|
/// Handle inline HTML, code spans, and links.
fn Parser::handle_inline_pass1(self : Parser) -> Unit {
  let mut cur : Int? = self.tree.cur()
  let mut prev : Int? = None

  let block_end = self.tree.nodes[self.tree.peek_up().unwrap()].item.end
  let block_text = self.text.exact_view(start=0, end=block_end)

  while true {
    guard cur is Some(cur_ix) else { break }
    let mut cur_ix = cur_ix
    match self.tree.nodes[cur_ix].item.body {
      MaybeHtml => {
        let next = self.tree.nodes[cur_ix].next
        let autolink = next.bind(next_ix => {
          scan_autolink(block_text, self.tree.nodes[next_ix].item.start)
        })

        match autolink {
          Some((ix, uri, link_type)) => {
            let node = scan_nodes_to_ix(self.tree, next, ix)
            let text_node = self.tree.create_node(Item::{
              start: self.tree.nodes[cur_ix].item.start + 1,
              end: ix - 1,
              body: Text(false),
            })
            let link_ix = self.allocs.allocate_link(link_type, uri, "", "")
            self.tree.nodes[cur_ix].item.body = Link(link_ix)
            self.tree.nodes[cur_ix].item.end = ix
            self.tree.nodes[cur_ix].next = node
            self.tree.nodes[cur_ix].child = Some(text_node)
            prev = cur
            cur = node
            if cur is Some(node_ix) {
              self.tree.nodes[node_ix].item.start = self.tree.nodes[node_ix].item.start.max(
                ix,
              )
            }
            continue
          }
          None => {
            let inline_html = next.bind(next_ix => {
              self.scan_inline_html(
                block_text,
                self.tree.nodes[next_ix].item.start,
              )
            })
            guard inline_html is Some((span, ix)) else { () }
            let node = scan_nodes_to_ix(self.tree, next, ix)
            self.tree.nodes[cur_ix].item.body = if !span.is_empty() {
              let converted_string = @utf8.decode_lossy(
                Bytes::from_array(span).exact_view(),
              )
              OwnedInlineHtml(
                self.allocs.allocate_cow(replace_nuls(converted_string)),
              )
            } else {
              InlineHtml
            }
            self.tree.nodes[cur_ix].item.end = ix
            self.tree.nodes[cur_ix].next = node
            prev = cur
            cur = node
            if cur is Some(node_ix) {
              self.tree.nodes[node_ix].item.start = self.tree.nodes[node_ix].item.start.max(
                ix,
              )
            }
            continue
          }
        }
        self.tree.nodes[cur_ix].item.body = Text(false)
      }
      MaybeMath(can_open, _can_close, brace_context) => {
        guard can_open else {
          self.tree.nodes[cur_ix].item.body = Text(false)
          prev = cur
          cur = self.tree.nodes[cur_ix].next
          continue
        }
        let is_display = self.tree.nodes[cur_ix].next.map_or(false, next_ix => {
          self.tree.nodes[next_ix].item.body is MaybeMath(_, _, _)
        })
        let result = if self.math_delims.is_populated() {
          // we have previously scanned all math environment delimiters
          self.math_delims.find(self.tree, cur_ix, is_display, brace_context)
        } else {
          // we haven't previously scanned all math delimiters
          let mut scan = self.tree.nodes[cur_ix].next
          if is_display && scan is Some(s) {
            // a display delimiter, `$$`, is actually two delimiters
            scan = self.tree.nodes[s].next
          }
          let mut invalid = false
          while true {
            guard scan is Some(scan_ix) else { break }
            match self.tree.nodes[scan_ix].item.body {
              MaybeMath(_can_open, can_close, delim_brace_context) => {
                let delim_is_display = self.tree.nodes[scan_ix].next.map_or(
                  false,
                  next_ix => {
                    self.tree.nodes[next_ix].item.body is MaybeMath(_, _, _)
                  },
                )
                let use_it = !invalid && delim_brace_context == brace_context
                if use_it {
                  if (!is_display && can_close) ||
                    (is_display && delim_is_display) {
                    // This will skip ahead past everything we just inserted.
                    self.math_delims.clear()
                    break
                  } else {
                    // Math cannot contain $, so the current item is invalid.
                    invalid = true
                  }
                }
                self.math_delims.insert(
                  delim_is_display, delim_brace_context, scan_ix, can_close,
                )
              }
              _ => ()
            }
            scan = self.tree.nodes[scan_ix].next
          }
          scan
        }

        if result is Some(scan_ix) {
          self.make_math_span(cur_ix, scan_ix)
        } else {
          self.tree.nodes[cur_ix].item.body = Text(false)
        }
      }
      MaybeCode(search_count, preceded_by_backslash) => {
        let mut search_count = search_count
        if preceded_by_backslash {
          search_count -= 1
          guard search_count != 0 else {
            self.tree.nodes[cur_ix].item.body = Text(false)
            prev = cur
            cur = self.tree.nodes[cur_ix].next
            continue
          }
        }

        if self.code_delims.is_populated() {
          // we have previously scanned all codeblock delimiters
          if self.code_delims.find(cur_ix, search_count) is Some(scan_ix) {
            self.make_code_span(cur_ix, scan_ix, preceded_by_backslash)
          } else {
            self.tree.nodes[cur_ix].item.body = Text(false)
          }
        } else {
          // we haven't previously scanned all codeblock delimiters
          let mut scan = if search_count > 0 {
            self.tree.nodes[cur_ix].next
          } else {
            None
          }
          while true {
            guard scan is Some(scan_ix) else { break }
            match self.tree.nodes[scan_ix].item.body {
              MaybeCode(delim_count, _) =>
                if search_count == delim_count {
                  self.make_code_span(cur_ix, scan_ix, preceded_by_backslash)
                  self.code_delims.clear()
                  break
                } else {
                  self.code_delims.insert(delim_count, scan_ix)
                }
              _ => ()
            }
            scan = self.tree.nodes[scan_ix].next
          }
          if scan is None {
            self.tree.nodes[cur_ix].item.body = Text(false)
          }
        }
      }
      MaybeLinkOpen => {
        self.tree.nodes[cur_ix].item.body = Text(false)
        let link_open_doubled = self.tree.nodes[cur_ix].next.map_or(false, ix => {
          self.tree.nodes[ix].item.body is MaybeLinkOpen
        })
        if self.options.contains(enable_wikilinks()) && link_open_doubled {
          self.wikilink_stack.push(LinkStackEl::{ node: cur_ix, ty: Link, })
        }
        self.link_stack.push(LinkStackEl::{ node: cur_ix, ty: Link, })
      }
      MaybeImage => {
        self.tree.nodes[cur_ix].item.body = Text(false)
        let link_open_doubled = self.tree.nodes[cur_ix].next.map_or(false, ix => {
          self.tree.nodes[ix].item.body is MaybeLinkOpen
        })
        if self.options.contains(enable_wikilinks()) && link_open_doubled {
          self.wikilink_stack.push(LinkStackEl::{ node: cur_ix, ty: Image, })
        }
        self.link_stack.push(LinkStackEl::{ node: cur_ix, ty: Image, })
      }
      MaybeLinkClose(could_be_ref) => {
        self.tree.nodes[cur_ix].item.body = Text(false)
        let tos_link = self.link_stack.pop()
        let next_is_link_close = self.tree.nodes[cur_ix].next.map_or(false, ix => {
          self.tree.nodes[ix].item.body is MaybeLinkClose(_)
        })
        let is_wikilink_close = self.options.contains(enable_wikilinks()) &&
          next_is_link_close
        if is_wikilink_close {
          guard self.handle_wikilink(block_text, cur_ix, prev) is Some(node) else {
            ()
          }
          prev = Some(node)
          cur = self.tree.nodes[node].next
          continue
        }
        guard tos_link is Some(tos) else { () }
        // skip rendering if already in a link, unless its an image
        let parent_is_link = self.tree.nodes[self.tree.peek_up().unwrap()].item.body
          is Link(_)
        let in_link = !(tos.ty is Image) && parent_is_link
        guard !in_link else { continue }
        guard !(tos.ty is Disabled) else { continue }
        let next = self.tree.nodes[cur_ix].next
        match
          self.scan_inline_link(
            block_text,
            self.tree.nodes[cur_ix].item.end,
            next,
          ) {
          Some((next_ix, url, title)) => {
            let next_node = scan_nodes_to_ix(self.tree, next, next_ix)
            if prev is Some(prev_ix) {
              self.tree.nodes[prev_ix].next = None
            }
            cur = Some(tos.node)
            cur_ix = tos.node
            let link_ix = self.allocs.allocate_link(Inline, url, title, "")
            self.tree.nodes[cur_ix].item.body = if tos.ty is Image {
              Image(link_ix)
            } else {
              Link(link_ix)
            }
            self.tree.nodes[cur_ix].child = self.tree.nodes[cur_ix].next
            self.tree.nodes[cur_ix].next = next_node
            self.tree.nodes[cur_ix].item.end = next_ix
            if next_node is Some(next_node_ix) {
              self.tree.nodes[next_node_ix].item.start = self.tree.nodes[next_node_ix].item.start.max(
                next_ix,
              )
            }

            if tos.ty is Link {
              self.disable_all_links()
            }
          }
          None => {
            // ok, so its not an inline link. maybe it is a reference
            let scan_result = scan_reference(
              self.tree,
              block_text,
              cur_ix,
              self.options,
            )
            let (node_after_link, link_type) = match scan_result {
              // [label][reference]
              RefScan::LinkLabel(_, end_ix) => {
                guard scan_nodes_to_ix(self.tree, next, end_ix - 1)
                  is Some(reference_close_node) else {
                  continue
                }
                self.tree.nodes[reference_close_node].item.body = MaybeLinkClose(
                  false,
                )
                let next_node = self.tree.nodes[reference_close_node].next

                (next_node, Reference)
              }
              // [reference][]
              RefScan::Collapsed(next_node) => {
                guard could_be_ref else { continue }
                (next_node, Collapsed)
              }
              // [shortcut]
              RefScan::Failed | RefScan::UnexpectedFootnote => {
                guard could_be_ref else { continue }
                (next, Shortcut)
              }
            }

            let label : (ReferenceLabel, Int)? = match scan_result {
              RefScan::LinkLabel(l, end_ix) =>
                Some((ReferenceLabel::Link(l), end_ix))
              RefScan::Collapsed(_)
              | RefScan::Failed
              | RefScan::UnexpectedFootnote => {
                // No label? maybe it is a shortcut reference
                let label_start = self.tree.nodes[tos.node].item.end - 1
                let label_end = self.tree.nodes[cur_ix].item.end
                scan_link_label(
                  self.tree,
                  self.text.exact_view(start=label_start, end=label_end),
                  self.options,
                ).bind(result => {
                  let (ix, label) = result
                  guard label_start + ix == label_end else { None }
                  Some((label, label_start + ix))
                })
              }
            }

            let id = label.map_or("", entry => {
              let (label, _) = entry
              match label {
                ReferenceLabel::Link(l) | ReferenceLabel::Footnote(l) => l
              }
            })

            // see if it's a footnote reference
            guard label is Some(label) else { () }
            match label {
              (ReferenceLabel::Footnote(l), end) => {
                let footref = self.allocs.allocate_cow(l)
                let folded_label = unicase_fold(l)
                if self.allocs.footdefs.contains(folded_label) {
                  let def = self.allocs.footdefs[folded_label]
                  def._use_count += 1
                  self.allocs.footdefs[folded_label] = def
                }
                let should_emit = !self.options.options_has_gfm_footnotes() ||
                  self.allocs.footdefs.contains(folded_label)
                if should_emit {
                  let footnote_ix = if tos.ty is Image {
                    self.tree.nodes[tos.node].next = Some(cur_ix)
                    self.tree.nodes[tos.node].child = None
                    self.tree.nodes[tos.node].item.body = SynthesizeChar('!')
                    self.tree.nodes[cur_ix].item.start = self.tree.nodes[tos.node].item.start +
                      1
                    self.tree.nodes[tos.node].item.end = self.tree.nodes[tos.node].item.start +
                      1
                    cur_ix
                  } else {
                    tos.node
                  }
                  self.tree.nodes[footnote_ix].next = next
                  self.tree.nodes[footnote_ix].child = None
                  self.tree.nodes[footnote_ix].item.body = FootnoteReference(
                    footref,
                  )
                  self.tree.nodes[footnote_ix].item.end = end
                  prev = Some(footnote_ix)
                  cur = next
                  self.link_stack.clear()
                  continue
                }
              }
              (ReferenceLabel::Link(link_label), end) =>
                if self.fetch_link_type_url_title(
                    link_label,
                    (self.tree.nodes[tos.node].item.start, end),
                    link_type,
                  )
                  is Some((def_link_type, url, title)) {
                  let link_ix = self.allocs.allocate_link(
                    def_link_type, url, title, id,
                  )
                  self.tree.nodes[tos.node].item.body = if tos.ty is Image {
                    Image(link_ix)
                  } else {
                    Link(link_ix)
                  }
                  let label_node = self.tree.nodes[tos.node].next

                  // lets do some tree surgery to add the link to the tree
                  self.tree.nodes[tos.node].next = node_after_link

                  if label_node != cur {
                    self.tree.nodes[tos.node].child = label_node

                    // finally: disconnect list of children
                    if prev is Some(prev_ix) {
                      self.tree.nodes[prev_ix].next = None
                    }
                  }

                  self.tree.nodes[tos.node].item.end = end

                  // set up cur so next node will be node_after_link
                  cur = Some(tos.node)
                  cur_ix = tos.node

                  if tos.ty is Link {
                    self.disable_all_links()
                  }
                }
            }
          }
        }
      }
      _ => ()
    }
    prev = cur
    cur = self.tree.nodes[cur_ix].next
  }
  self.link_stack.clear()
  self.wikilink_stack.clear()
  self.code_delims.clear()
  self.math_delims.clear()
}

///|
priv enum ReferenceLabel {
  Link(String)
  Footnote(String)
}

///|
priv enum RefScan {
  // label, source ix of label end
  LinkLabel(String, Int)
  // contains next node index
  Collapsed(Int?)
  UnexpectedFootnote
  Failed
}

///|
/// Skips forward within a block to a node which spans (ends inclusive) the given
/// index into the source.
fn scan_nodes_to_ix(tree : Tree[Item], node : Int?, ix : Int) -> Int? {
  for node = node {
    guard node is Some(node_ix) && tree.nodes[node_ix].item.end <= ix else {
      break node
    }
    continue tree.nodes[node_ix].next
  }
}

///|
/// Scans an inline link label, which cannot be interrupted.
fn scan_link_label(
  tree : Tree[Item],
  text : BytesView,
  options : Options,
) -> (Int, ReferenceLabel)? {
  let bytes = text
  guard bytes.length() >= 2 && bytes.unsafe_get(0) == b'[' else { return None }
  let is_footnote = options.contains(enable_footnotes()) &&
    bytes.length() > 2 &&
    bytes.unsafe_get(1) == b'^' &&
    bytes.unsafe_get(2) != b']'
  if is_footnote {
    let handler : ((BytesView) -> Int?)? = if options.options_has_gfm_footnotes() {
      None
    } else {
      Some((bytes : BytesView) => {
        Some(skip_container_prefixes(tree, bytes, options))
      })
    }
    guard scan_link_label_rest(text, 2, handler, tree.is_in_table())
      is Some((byte_index, cow)) else {
      ()
    }
    return Some((byte_index + 2, ReferenceLabel::Footnote(cow)))
  }
  let handler : ((BytesView) -> Int?)? = Some((bytes : BytesView) => {
    Some(skip_container_prefixes(tree, bytes, options))
  })
  scan_link_label_rest(text, 1, handler, tree.is_in_table()).map(label => {
    let (byte_index, cow) = label
    (byte_index + 1, ReferenceLabel::Link(cow))
  })
}

///|
fn scan_reference(
  tree : Tree[Item],
  text : BytesView,
  cur_ix : Int,
  options : Options,
) -> RefScan {
  let start = tree.nodes[cur_ix].item.end
  let tail = text.exact_view(start~)

  if tail.has_prefix(b"[]".exact_view()) {
    guard tree.nodes[cur_ix].next is Some(next_ix) &&
      tree.nodes[next_ix].item.start == tree.nodes[cur_ix].item.end else {
      return RefScan::Failed
    }
    guard tree.nodes[next_ix].next is Some(closing_node) else {
      return RefScan::Failed
    }
    RefScan::Collapsed(tree.nodes[closing_node].next)
  } else {
    guard scan_link_label(tree, text.exact_view(start~), options)
      is Some((ix, label)) else {
      return RefScan::Failed
    }
    match label {
      ReferenceLabel::Link(label) => RefScan::LinkLabel(label, start + ix)
      ReferenceLabel::Footnote(_) => RefScan::UnexpectedFootnote
    }
  }
}

///|
fn replace_nuls(s : String) -> String {
  s.replace_all(old="\u{0}", new="\u{fffd}")
}

///|
priv struct LinkStackEl {
  node : Int
  mut ty : LinkStackTy
}

///|
priv enum LinkStackTy {
  Link
  Image
  Disabled
}

///|
struct LinkStack {
  inner : Array[LinkStackEl]
  mut disabled_ix : Int
}

///|
fn link_stack_new() -> LinkStack {
  { inner: [], disabled_ix: 0, }
}

///|
fn LinkStack::push(self : LinkStack, el : LinkStackEl) -> Unit {
  self.inner.push(el)
}

///|
fn LinkStack::pop(self : LinkStack) -> LinkStackEl? {
  let el = self.inner.pop()
  self.disabled_ix = self.disabled_ix.min(self.inner.length())
  el
}

///|
fn LinkStack::clear(self : LinkStack) -> Unit {
  self.inner.clear()
  self.disabled_ix = 0
}

///|
fn LinkStack::disable_all_links(self : LinkStack) -> Unit {
  for i in self.disabled_ix..<self.inner.length() {
    if self.inner[i].ty is Link {
      self.inner[i].ty = Disabled
    }
  }
  self.disabled_ix = self.inner.length()
}
