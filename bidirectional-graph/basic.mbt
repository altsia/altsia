///|
fn[Node : Hash + Eq] singleton(node : Node) -> @hashset.HashSet[Node] {
  let set = @hashset.HashSet::new()
  set.add(node)
  set
}

///|
pub fn[Node] BidirectionalGraph::new(
  max_cache_n? : Int = 2,
) -> BidirectionalGraph[Node] {
  {
    out_edges: @hashmap.HashMap::new(),
    in_edges: @hashmap.HashMap::new(),
    forward_cache: @hashmap.HashMap::new(),
    backward_cache: @hashmap.HashMap::new(),
    max_cache_n: if max_cache_n < 0 {
      0
    } else {
      max_cache_n
    },
  }
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::add_edge(
  self : BidirectionalGraph[Node],
  u : Node,
  v : Node,
) -> Unit {
  let out_neighbors = self.out_edges.get_or_default(u, @hashset.HashSet::new())
  out_neighbors.add(v)
  self.out_edges.set(u, out_neighbors)

  let in_neighbors = self.in_edges.get_or_default(v, @hashset.HashSet::new())
  in_neighbors.add(u)
  self.in_edges.set(v, in_neighbors)

  self.invalidate_caches_for_node(u)
  self.invalidate_caches_for_node(v)
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::remove_edge(
  self : BidirectionalGraph[Node],
  u : Node,
  v : Node,
) -> Bool {
  match self.out_edges.get(u) {
    None => false
    Some(current_out_neighbors) => {
      let out_neighbors = current_out_neighbors.copy()
      guard out_neighbors.remove_and_check(v) else { return false }

      if out_neighbors.is_empty() {
        self.out_edges.remove(u)
      } else {
        self.out_edges.set(u, out_neighbors)
      }

      if self.in_edges.get(v) is Some(current_in_neighbors) {
        let in_neighbors = current_in_neighbors.copy()
        ignore(in_neighbors.remove_and_check(u))
        if in_neighbors.is_empty() {
          self.in_edges.remove(v)
        } else {
          self.in_edges.set(v, in_neighbors)
        }
      }

      self.invalidate_caches_for_node(u)
      self.invalidate_caches_for_node(v)
      true
    }
  }
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::extend_edges(
  self : BidirectionalGraph[Node],
  edges : ArrayView[(Node, Node)],
) -> Unit {
  edges.each(edge => self.add_edge(edge.0, edge.1))
}

///|
pub fn[Node] BidirectionalGraph::clear_caches(
  self : BidirectionalGraph[Node],
) -> Unit {
  self.forward_cache.clear()
  self.backward_cache.clear()
}

///|
fn[Node : Hash + Eq] BidirectionalGraph::invalidate_caches_for_node(
  self : BidirectionalGraph[Node],
  node : Node,
) -> Unit {
  if self.max_cache_n <= 0 {
    return
  }
  for n in 1..<=self.max_cache_n {
    self.forward_cache.remove((node, n))
    self.backward_cache.remove((node, n))
  }
}
