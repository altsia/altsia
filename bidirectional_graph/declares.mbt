///|
pub struct BidirectionalGraph[Node] {
  out_edges : @hashmap.HashMap[Node, @hashset.HashSet[Node]]
  in_edges : @hashmap.HashMap[Node, @hashset.HashSet[Node]]
  forward_cache : @hashmap.HashMap[(Node, Int), @hashset.HashSet[Node]]
  backward_cache : @hashmap.HashMap[(Node, Int), @hashset.HashSet[Node]]
  max_cache_n : Int
}
