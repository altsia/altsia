///|
fn char_at(source : String, i : Int) -> Char {
  source.get_char(i).unwrap()
}

///|
pub fn[E : Show] join_list(
  list : @list.List[E],
  separator? : String = ", ",
) -> String {
  match list {
    Empty => ""
    More(x, tail~) =>
      tail.fold(init=x.to_string(), (s, t) => "\{s}\{separator}\{t}")
  }
}
