///|
/// The fields of a `Block::Element` unwrapped from its constructor, so
/// element renderers take one structure instead of three parameters.
pub(all) struct ElementData {
  tag : String
  positional : Array[@parsing.Value]
  named : Map[String, @parsing.Value]
}

///|
/// The block flow contributed by an element's content arguments: every
/// positional `Content` value, in order. Mirrors the argument model where
/// a call's trailing content block is a positional `Content` argument
/// (`elem[bbb] ≡ elem([bbb])`).
fn ElementData::children(self : ElementData) -> Array[@parsing.Block] {
  self.positional
  .filter_map(value => {
    guard value is @parsing.Content(blocks) else { return None }
    Some(blocks)
  })
  .flatten()
}
