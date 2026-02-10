///|
pub(all) enum Term {
  Text(String)
  App(Name, Array[Term])
  Splice(Array[Term]) // App("_", [...])
  Comment(String) // App("%", [...])
} derive(Eq, Show, Debug)

///|
pub type Name = String

///|
pub type Stage2

///|
let empty : Term = Text("")

///|
fn elaborate_name(s : S) -> Name {
  match s {
    Text(s) => s
    _ => try! fail("the function name \{s} must be pure text ㊔")
  }
}

///|
fn elaborate_comment(xs : ArrayView[S]) -> String {
  match xs {
    [] => ""
    [Text(s)] => s
    _ => xs.map(x => x.to_source()).join(" ")
  }
}

///|
fn elaborate_app(data : @list.List[S]) -> Term {
  let view = data.to_array()
  match view {
    [] => empty
    [f, .. xs] =>
      match elaborate_name(f) {
        "%" => Comment(elaborate_comment(xs))
        "_" => Splice(xs.map(Stage2::elaborate_node))
        s => App(s, xs.map(Stage2::elaborate_node))
      }
  }
}

///|
pub fn Stage2::elaborate_node(node : S) -> Term {
  match node {
    Text(s) => Text(s)
    Block(s) => Text(s) // raw block -> text
    App(xs) => elaborate_app(xs)
  }
}

///|
pub fn Stage2::pass(nodes : Array[S]) -> Array[Term] {
  nodes.map(Stage2::elaborate_node)
}
