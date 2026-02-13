///|
pub(all) enum Term {
  Text(String)
  App(Name, Array[Term])
  TemplateDefinition(Name, Array[Name], Array[Term])
  Splice(Array[Term]) // App("_", [...])
  Comment(String) // App("%", [...])
} derive(Eq, Show, Debug)

///|
pub(all) enum LocatedTerm {
  TText(String, SourceLoc)
  TApp(Name, Array[LocatedTerm], SourceLoc)
  TTemplateDefinition(Name, Array[Name], Array[LocatedTerm], SourceLoc)
  TSplice(Array[LocatedTerm], SourceLoc)
  TComment(String, SourceLoc)
} derive(Eq, Show, Debug)

///|
pub fn LocatedTerm::loc(node : LocatedTerm) -> SourceLoc {
  match node {
    TText(_, loc) => loc
    TApp(_, _, loc) => loc
    TTemplateDefinition(_, _, _, loc) => loc
    TSplice(_, loc) => loc
    TComment(_, loc) => loc
  }
}

///|
pub fn LocatedTerm::to_term(node : LocatedTerm) -> Term {
  match node {
    TText(s, _) => Text(s)
    TApp(name, args, _) => App(name, args.map(LocatedTerm::to_term))
    TTemplateDefinition(name, params, body, _) =>
      TemplateDefinition(name, params, body.map(LocatedTerm::to_term))
    TSplice(terms, _) => Splice(terms.map(LocatedTerm::to_term))
    TComment(c, _) => Comment(c)
  }
}

///|
pub type Name = String

///|
pub type Stage2

///|
pub(all) suberror Stage2Error {
  FunctionNameMustBePlainText(found~ : S, loc~ : SourceLoc?)
  TemplateRequiresNameAndParamList(items~ : Array[S], loc~ : SourceLoc?)
  TemplateParamsMustBeList(found~ : S, loc~ : SourceLoc?)
  InternalInvariantViolation(context~ : String, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
let empty : Term = Text("")

///|
fn elaborate_name(s : S) -> Name raise {
  match s {
    Text(s) => s
    _ => raise Stage2Error::FunctionNameMustBePlainText(found=s, loc=None)
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
fn elaborate_template(xs : ArrayView[S]) -> Term raise {
  if xs.length() < 2 {
    raise Stage2Error::TemplateRequiresNameAndParamList(
      items=xs.to_array(),
      loc=None,
    )
  }
  let name = elaborate_name(xs[0])
  let params = match xs[1] {
    App(list) => list.to_array().map(elaborate_name)
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

///|
fn erase_spanned_nodes(xs : ArrayView[SpannedS]) -> Array[S] {
  let result = []
  for x in xs {
    result.push(SpannedS::erase_span(x))
  }
  result
}

///|
fn elaborate_name_spanned(node : SpannedS) -> Name raise {
  match node {
    Text(s, _) => s
    _ =>
      raise Stage2Error::FunctionNameMustBePlainText(
        found=SpannedS::erase_span(node),
        loc=Some(node.loc()),
      )
  }
}

///|
fn elaborate_comment_spanned(xs : ArrayView[SpannedS]) -> String {
  match xs {
    [] => ""
    [Text(s, _)] => s
    _ => xs.map(x => SpannedS::erase_span(x).to_source()).join(" ")
  }
}

///|
fn elaborate_nodes_spanned(xs : ArrayView[SpannedS]) -> Array[LocatedTerm] raise {
  let result = []
  for x in xs {
    result.push(Stage2::elaborate_node_spanned(x))
  }
  result
}

///|
fn elaborate_template_spanned(
  xs : ArrayView[SpannedS],
  app_loc : SourceLoc,
) -> LocatedTerm raise {
  if xs.length() < 2 {
    raise Stage2Error::TemplateRequiresNameAndParamList(
      items=erase_spanned_nodes(xs),
      loc=Some(app_loc),
    )
  }
  let name = elaborate_name_spanned(xs[0])
  let params = match xs[1] {
    App(list, _) => list.map(elaborate_name_spanned)
    _ =>
      raise Stage2Error::TemplateParamsMustBeList(
        found=SpannedS::erase_span(xs[1]),
        loc=Some(xs[1].loc()),
      )
  }
  let body = elaborate_nodes_spanned(xs[2:])
  TTemplateDefinition(name, params, body, app_loc)
}

///|
fn elaborate_app_spanned(node : SpannedS) -> LocatedTerm raise {
  match node {
    App(view, app_loc) =>
      match view {
        [] => TText("", app_loc)
        [f, .. xs] =>
          match elaborate_name_spanned(f) {
            "%" => TComment(elaborate_comment_spanned(xs), app_loc)
            "_" => TSplice(elaborate_nodes_spanned(xs), app_loc)
            "~" => {
              let body = elaborate_nodes_spanned(xs)
              TSplice([TText(" ", app_loc), ..body, TText(" ", app_loc)], app_loc)
            }
            "λ" => elaborate_template_spanned(xs, app_loc)
            s => TApp(s, elaborate_nodes_spanned(xs), app_loc)
          }
      }
    _ =>
      raise Stage2Error::InternalInvariantViolation(
        context="elaborate_app_spanned expects an App node",
        loc=Some(node.loc()),
      )
  }
}

///|
pub fn Stage2::elaborate_node_spanned(node : SpannedS) -> LocatedTerm raise {
  match node {
    Text(s, loc) => TText(s, loc)
    Quote(s, loc) => TText(s, loc) // raw block -> text
    App(_, _) => elaborate_app_spanned(node)
  }
}

///|
pub fn Stage2::pass_spanned(nodes : Array[SpannedS]) -> Array[LocatedTerm] raise {
  let result = []
  for node in nodes {
    result.push(Stage2::elaborate_node_spanned(node))
  }
  result
}
