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
fn elaborate_params_name_spanned(node : SpannedS) -> Name raise {
  match node {
    Text(s, _) => s
    App(list, loc) =>
      match list {
        [head, ..] => elaborate_name_spanned(head)
        [] =>
          raise Stage2Error::TemplateParamApplicationMissingHead(
            found=SpannedS::erase_span(node),
            loc=Some(loc),
          )
      }
    _ =>
      raise Stage2Error::FunctionNameMustBePlainText(
        found=SpannedS::erase_span(node),
        loc=Some(node.loc()),
      )
  }
}

///|
fn elaborate_nodes_spanned(
  xs : ArrayView[SpannedS],
) -> Array[LocatedTerm] raise {
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
    App(list, _) => list.map(elaborate_params_name_spanned)
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
              TSplice(
                [TText(" ", app_loc), ..body, TText(" ", app_loc)],
                app_loc,
              )
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
pub fn Stage2::pass_spanned(
  nodes : Array[SpannedS],
) -> Array[LocatedTerm] raise {
  let result = []
  for node in nodes {
    result.push(Stage2::elaborate_node_spanned(node))
  }
  result
}
