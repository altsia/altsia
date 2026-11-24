// A vec-based container for a tree structure.
//
// `TreeIndex` values start at 1; index 0 is a dummy node so that `Array`'s
// default `get` behavior works without subtracting one everywhere.

///|
/// A node in the tree.
priv struct Node[T] {
  mut child : Int32?
  mut next : Int32?
  item : T
}

///|
/// A tree abstraction, intended for fast building as a preorder traversal.
struct Tree[T] {
  nodes : Array[Node[T]]
  spine : Array[Int32] // indices of nodes on path to current node
  mut cur : Int32?
}

///|
fn[T : Default] tree_with_capacity(_cap : Int32) -> Tree[T] {
  let nodes : Array[Node[T]] = Array::make(1, {
    child: None,
    next: None,
    item: T::default(),
  })
  { nodes, spine: [], cur: None, }
}

///|
/// Returns the index of the element currently in focus.
fn[T] Tree::cur(self : Tree[T]) -> Int32? {
  self.cur
}

///|
/// Append one item to the current position in the tree.
fn[T] Tree::append(self : Tree[T], item : T) -> Int32 {
  let ix = self.create_node(item)
  if self.cur is Some(cur) {
    self.nodes[cur].next = Some(ix)
  } else if self.spine.last() is Some(parent) {
    self.nodes[parent].child = Some(ix)
  }
  self.cur = Some(ix)
  ix
}

///|
/// Create an isolated node.
fn[T] Tree::create_node(self : Tree[T], item : T) -> Int32 {
  let this = self.nodes.length()
  self.nodes.push({ child: None, next: None, item, })
  this
}

///|
/// Push down one level, so that new items become children of the current node.
/// The new focus index is returned.
fn[T] Tree::push(self : Tree[T]) -> Int32 {
  let cur_ix = self.cur.unwrap()
  self.spine.push(cur_ix)
  self.cur = self.nodes[cur_ix].child
  cur_ix
}

///|
/// Pop back up a level.
fn[T] Tree::pop(self : Tree[T]) -> Int32? {
  let ix = self.spine.pop()
  self.cur = ix
  ix
}

///|
/// Remove the last node, as `pop` but removing it.
fn[T] Tree::remove_node(self : Tree[T]) -> Int32? {
  let ix = self.spine.pop()
  self.cur = ix
  guard ix is Some(i) else { return ix }
  if self.nodes.length() > 0 {
    ignore(self.nodes.pop())
    self.nodes[i].child = None
  }
  ix
}

///|
/// Look at the parent node.
fn[T] Tree::peek_up(self : Tree[T]) -> Int32? {
  self.spine.last()
}

///|
/// Look at grandparent node.
fn[T] Tree::peek_grandparent(self : Tree[T]) -> Int32? {
  guard self.spine.length() >= 2 else { None }
  Some(self.spine[self.spine.length() - 2])
}

///|
/// Returns true when there are no nodes other than the root node in the tree.
fn[T] Tree::is_empty(self : Tree[T]) -> Bool {
  self.nodes.length() <= 1
}

///|
/// Returns the length of the spine.
fn[T] Tree::spine_len(self : Tree[T]) -> Int32 {
  self.spine.length()
}

///|
/// Resets the focus to the first node added to the tree, if it exists.
fn[T] Tree::reset(self : Tree[T]) -> Unit {
  self.cur = if self.is_empty() { None } else { Some(1) }
  self.spine.clear()
}

///|
/// Iterates the spine from a root node up to, but not including, the current node.
fn[T] Tree::walk_spine(self : Tree[T]) -> Array[Int32] {
  self.spine.copy()
}

///|
/// Moves focus to the next sibling of the given node.
fn[T] Tree::next_sibling(self : Tree[T], cur_ix : Int32) -> Int32? {
  self.cur = self.nodes[cur_ix].next
  self.cur
}

///|
fn[T] Tree::truncate_to_parent(self : Tree[T], child_ix : Int32) -> Unit {
  let next = self.nodes[child_ix].next
  self.nodes[child_ix].next = None
  if self.cur is Some(cur) {
    self.nodes[cur].next = next
  } else if self.spine.last() is Some(parent) {
    self.nodes[parent].child = next
  }
  if next is Some(_) {
    self.cur = next
  }
}

///|
fn Tree::append_text(self : Tree[Item], start : Int32, end : Int32) -> Unit {
  if end > start {
    if self.cur() is Some(ix) {
      let merges = self.nodes[ix].item.body is Text &&
        self.nodes[ix].item.end == start
      if merges {
        self.nodes[ix].item.end = end
        return
      }
    }
    ignore(self.append(Item::{ start, end, body: Text, }))
  }
}

///|
/// Returns true if the current node is inside a table.
fn Tree::is_in_table(self : Tree[Item]) -> Bool {
  let spine = self.spine.copy()
  for idx in 0..<spine.length() {
    let ix = spine[spine.length() - 1 - idx]
    let item = self.nodes[ix].item
    if item.body is Table(_) {
      return true
    }
    let is_inline = item_body_is_inline(item.body)
    let is_table_part = item.body is (TableHead | TableRow | TableCell)
    guard is_inline || is_table_part else { return false }
  }
  false
}
