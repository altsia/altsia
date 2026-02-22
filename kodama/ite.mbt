///|
#inline
pub fn[X] ite_eager(condition : Bool, then_part : X, else_part : X) -> X {
  if condition {
    then_part
  } else {
    else_part
  }
}
