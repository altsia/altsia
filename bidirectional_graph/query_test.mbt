///|
fn assert_string_set_eq(
  actual : @hashset.HashSet[String],
  expected : Array[String],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  expected.each(value => assert_eq(actual.contains(value), true))
}

///|
test "bidirectional graph n-links basic" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new(max_cache_n=2)
  g.add_edge("A", "B")
  g.add_edge("B", "C")
  g.add_edge("A", "D")
  g.add_edge("D", "C")

  let l1 = g.n_links_forward("A", 1)
  assert_string_set_eq(l1, ["B", "D"])

  let l2 = g.n_links_forward("A", 2)
  assert_string_set_eq(l2, ["C"])

  let rev_l2 = g.n_links_backward("C", 2)
  assert_string_set_eq(rev_l2, ["A"])
}

///|
test "bidirectional graph remove edge" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new(max_cache_n=3)
  g.extend_edges([("A", "B"), ("B", "C"), ("A", "D"), ("D", "C")])

  assert_eq(g.remove_edge("A", "D"), true)
  assert_eq(g.remove_edge("A", "D"), false)

  let out = g.out_neighbors("A")
  assert_string_set_eq(out, ["B"])

  let in_set = g.in_neighbors("C")
  assert_string_set_eq(in_set, ["B", "D"])

  let l2 = g.n_links_forward("A", 2)
  assert_string_set_eq(l2, ["C"])
}

///|
test "bidirectional graph n=0 and negative" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new()
  g.extend_edges([("A", "B"), ("B", "C"), ("D", "A"), ("C", "D")])

  let self_set = g.n_links_forward("A", 0)
  assert_string_set_eq(self_set, ["A"])

  let negative = g.n_links_forward("A", -1)
  assert_string_set_eq(negative, ["D"])

  let mapped_forward = g.n_links_backward("A", 1)
  assert_string_set_eq(mapped_forward, ["D"])

  let negative_backward = g.n_links_backward("C", -2)
  assert_string_set_eq(negative_backward, ["A"])

  let mapped_backward = g.n_links_forward("C", 2)
  assert_string_set_eq(mapped_backward, ["A"])
}

///|
test "bidirectional graph bidirectional radius query follows both edge directions each step" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new()
  g.extend_edges([
    ("A", "B"),
    ("B", "C"),
    ("A", "F"),
    ("X", "B"),
    ("D", "A"),
    ("E", "D"),
  ])

  let distance2 = g.radius_links_bidirectional("A", 2)
  assert_string_set_eq(distance2, ["B", "C", "D", "E", "F", "X"])
}

///|
test "bidirectional graph bidirectional radius query uses absolute radius" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new()
  g.extend_edges([("A", "B"), ("B", "C"), ("D", "A")])

  let zero = g.radius_links_bidirectional("A", 0)
  assert_string_set_eq(zero, [])

  let mapped_radius1 = g.radius_links_bidirectional("A", -1)
  assert_string_set_eq(mapped_radius1, ["B", "D"])

  let mapped_radius2 = g.radius_links_bidirectional("A", -2)
  assert_string_set_eq(mapped_radius2, ["B", "C", "D"])
}

///|
test "bidirectional graph fixed-point optimization keeps self-loop semantics" {
  let g : BidirectionalGraph[String] = BidirectionalGraph::new()
  g.add_edge("A", "A")

  let forward = g.n_links_forward("A", 1_000_000)
  assert_string_set_eq(forward, ["A"])

  let backward = g.n_links_backward("A", 1_000_000)
  assert_string_set_eq(backward, ["A"])
}
