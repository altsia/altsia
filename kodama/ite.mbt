///|
pub fn[X] ite(condition : Bool, then_part : () -> X, else_part : () -> X) -> X {
  if condition {
    then_part()
  } else {
    else_part()
  }
}
