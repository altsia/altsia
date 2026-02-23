///|
/// specialize `Some(s).filter(s => !s.is_empty())`
pub fn non_empty(s : String) -> Option[String] {
  guard s.is_empty() else { Some(s) }
  None
}
