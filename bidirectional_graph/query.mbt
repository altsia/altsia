///|
pub fn[Node : Hash + Eq] BidirectionalGraph::out_neighbors(
  self : BidirectionalGraph[Node],
  node : Node,
) -> @hashset.HashSet[Node] {
  match self.out_edges.get(node) {
    None => @hashset.HashSet::new()
    Some(neighbors) => neighbors.copy()
  }
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::in_neighbors(
  self : BidirectionalGraph[Node],
  node : Node,
) -> @hashset.HashSet[Node] {
  match self.in_edges.get(node) {
    None => @hashset.HashSet::new()
    Some(neighbors) => neighbors.copy()
  }
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::n_links_forward(
  self : BidirectionalGraph[Node],
  node : Node,
  n : Int,
) -> @hashset.HashSet[Node] {
  if n == 0 {
    return singleton(node)
  }
  if n < 0 {
    return self.n_links_backward(node, -n)
  }

  if n <= self.max_cache_n {
    if self.forward_cache.get((node, n)) is Some(cached) {
      return cached.copy()
    }
    let result = self.compute_forward(node, n)
    self.forward_cache.set((node, n), result.copy())
    return result
  }

  self.compute_forward(node, n)
}

///|
fn[Node : Hash + Eq] hashset_eq(
  lhs : @hashset.HashSet[Node],
  rhs : @hashset.HashSet[Node],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut all_in_rhs = true
  lhs.each(v => {
    if !rhs.contains(v) {
      all_in_rhs = false
    }
  })
  all_in_rhs
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::n_links_backward(
  self : BidirectionalGraph[Node],
  node : Node,
  n : Int,
) -> @hashset.HashSet[Node] {
  if n == 0 {
    return singleton(node)
  }
  if n < 0 {
    return self.n_links_forward(node, -n)
  }

  if n <= self.max_cache_n {
    if self.backward_cache.get((node, n)) is Some(cached) {
      return cached.copy()
    }
    let result = self.compute_backward(node, n)
    self.backward_cache.set((node, n), result.copy())
    return result
  }

  self.compute_backward(node, n)
}

///|
pub fn[Node : Hash + Eq] BidirectionalGraph::radius_links_bidirectional(
  self : BidirectionalGraph[Node],
  node : Node,
  radius : Int,
) -> @hashset.HashSet[Node] {
  let steps = if radius < 0 { -radius } else { radius }
  let result = @hashset.HashSet::new()

  let mut frontier = singleton(node)
  for _ in 0..<steps {
    let next = @hashset.HashSet::new()
    frontier.each(current => {
      if self.out_edges.get(current) is Some(neighbors) {
        neighbors.each(next_node => {
          next.add(next_node)
          result.add(next_node)
        })
      }
      if self.in_edges.get(current) is Some(predecessors) {
        predecessors.each(next_node => {
          next.add(next_node)
          result.add(next_node)
        })
      }
    })
    frontier = next
    if frontier.is_empty() {
      break
    }
  }
  ignore(result.remove_and_check(node))
  result
}

///|
fn[Node : Hash + Eq] BidirectionalGraph::compute_forward(
  self : BidirectionalGraph[Node],
  start : Node,
  n : Int,
) -> @hashset.HashSet[Node] {
  let mut frontier = singleton(start)
  for _ in 0..<n {
    let next = @hashset.HashSet::new()
    frontier.each(u => {
      if self.out_edges.get(u) is Some(neighbors) {
        neighbors.each(v => next.add(v))
      }
    })
    if hashset_eq(next, frontier) {
      break
    }
    frontier = next
    if frontier.is_empty() {
      break
    }
  }
  frontier
}

///|
fn[Node : Hash + Eq] BidirectionalGraph::compute_backward(
  self : BidirectionalGraph[Node],
  start : Node,
  n : Int,
) -> @hashset.HashSet[Node] {
  let mut frontier = singleton(start)
  for _ in 0..<n {
    let next = @hashset.HashSet::new()
    frontier.each(v => {
      if self.in_edges.get(v) is Some(predecessors) {
        predecessors.each(u => next.add(u))
      }
    })
    if hashset_eq(next, frontier) {
      break
    }
    frontier = next
    if frontier.is_empty() {
      break
    }
  }
  frontier
}
