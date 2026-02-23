///|
/// specialize `Some(s).filter(s => !s.is_empty())`
pub fn non_empty(s : String) -> String? {
  guard s.is_empty() else { Some(s) }
  None
}
