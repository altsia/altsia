///|
pub(all) enum Term {
  Text(String)
  App(Name, Array[Term])
  TemplateDefinition(Name, Array[Name], Array[Term])
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
fn elaborate_template(xs : ArrayView[S]) -> Term {
  if xs.length() < 2 {
    try! fail("template requires name and param list: \{xs}")
  }
  let name = elaborate_name(xs[0])
  let params = match xs[1] {
    App(list) => list.to_array().map(elaborate_name)
    _ => try! fail("template params \{xs[1]} must be list")
  }
  let body = xs[2:].map(Stage2::elaborate_node)
  TemplateDefinition(name, params, body)
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
        "λ" => elaborate_template(xs)
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
