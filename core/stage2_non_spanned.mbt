///|
let empty : Term = Text("")

///|
fn elaborate_comment(xs : ArrayView[S]) -> String {
  match xs {
    [] => ""
    [Text(s)] => s
    _ => xs.map(x => x.to_source()).join(" ")
  }
}

///|
fn elaborate_name(s : S) -> Name raise {
  match s {
    Text(s) => s
    _ => raise Stage2Error::FunctionNameMustBePlainText(found=s, loc=None)
  }
}

///|
fn elaborate_params_name(term : S) -> Name raise {
  match term {
    Text(s) => s
    App(xs) =>
      match xs.head() {
        Some(head) => elaborate_name(head)
        None =>
          raise Stage2Error::TemplateParamApplicationMissingHead(
            found=term,
            loc=None,
          )
      }
    _ => raise Stage2Error::FunctionNameMustBePlainText(found=term, loc=None)
  }
}

///|
fn elaborate_template(xs : ArrayView[S]) -> Term raise {
  if xs.length() < 2 {
    raise Stage2Error::TemplateRequiresNameAndParamList(
      items=xs.to_array(),
      loc=None,
    )
  }
  let name = elaborate_name(xs[0])
  let params = match xs[1] {
    App(list) => list.to_array().map(elaborate_params_name)
    _ => raise Stage2Error::TemplateParamsMustBeList(found=xs[1], loc=None)
  }
  let body = xs[2:].map(Stage2::elaborate_node)
  TemplateDefinition(name, params, body)
}

///|
fn elaborate_app(data : @list.List[S]) -> Term raise {
  let view = data.to_array()
  match view {
    [] => empty
    [f, .. xs] =>
      match elaborate_name(f) {
        "%" => Comment(elaborate_comment(xs))
        "_" => Splice(xs.map(Stage2::elaborate_node))
        "~" => Splice([Text(" "), ..xs.map(Stage2::elaborate_node), Text(" ")])
        "λ" => elaborate_template(xs)
        s => App(s, xs.map(Stage2::elaborate_node))
      }
  }
}

///|
pub fn Stage2::elaborate_node(node : S) -> Term raise {
  match node {
    Text(s) => Text(s)
    Quote(s) => Text(s) // raw block -> text
    App(xs) => elaborate_app(xs)
  }
}

///|
pub fn Stage2::pass(nodes : Array[S]) -> Array[Term] raise {
  nodes.map(Stage2::elaborate_node)
}
