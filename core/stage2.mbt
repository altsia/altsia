///|
pub(all) enum Term {
  Text(String, SourceLoc)
  App(Name, Array[Term], SourceLoc)
  TemplateDefinition(
    Name,
    Array[Name],
    Array[(Name, Array[Term])],
    Array[Term],
    SourceLoc
  )
  Splice(Array[Term], SourceLoc)
  Comment(String, SourceLoc)
} derive(Eq, Show, Debug)

///|
pub fn Term::loc(node : Term) -> SourceLoc {
  match node {
    Text(_, loc) => loc
    App(_, _, loc) => loc
    TemplateDefinition(_, _, _, _, loc) => loc
    Splice(_, loc) => loc
    Comment(_, loc) => loc
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
  TemplateParamApplicationMissingHead(found~ : S, loc~ : SourceLoc?)
  InternalInvariantViolation(context~ : String, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
fn erase_nodes(xs : ArrayView[S]) -> Array[S] {
  let result = []
  for x in xs {
    result.push(x)
  }
  result
}

///|
#alias(elaborate_string_literal)
pub fn elaborate_name(node : S) -> Name raise {
  match node {
    Text(s, _) => s
    _ =>
      raise Stage2Error::FunctionNameMustBePlainText(
        found=node,
        loc=Some(node.loc()),
      )
  }
}

///|
fn elaborate_comment(xs : ArrayView[S]) -> String {
  match xs {
    [] => ""
    [Text(s, _)] => s
    _ => xs.map(ToSource::to_source).join(" ")
  }
}

///|
pub fn Stage2::is_named_param(name : Name) -> Bool {
  name.has_prefix(":")
}

///|
pub fn Stage2::extract_named_param(name : Name) -> StringView? {
  name.strip_prefix(":")
}

///|
fn elaborate_param_spec(node : S) -> (Name, Array[Term]?) raise {
  match node {
    Text(s, _) => (s, None)
    App(list, gaps, loc) =>
      match list {
        [head, .. tail] => {
          let name = elaborate_name(head)
          if Stage2::is_named_param(name) && !tail.is_empty() {
            (name, Some(elaborate_nodes_with_gaps(tail, gaps, 1)))
          } else {
            (name, None)
          }
        }
        [] =>
          raise Stage2Error::TemplateParamApplicationMissingHead(
            found=node,
            loc=Some(loc),
          )
      }
    _ =>
      raise Stage2Error::FunctionNameMustBePlainText(
        found=node,
        loc=Some(node.loc()),
      )
  }
}

///|
fn elaborate_nodes(xs : ArrayView[S]) -> Array[Term] raise {
  let result = []
  for x in xs {
    result.push(Stage2::elaborate_node(x))
  }
  result
}

///|
fn gap_separator_loc(next : S) -> SourceLoc {
  let loc = next.loc()
  {
    start_offset: loc.start_offset,
    end_offset: loc.start_offset,
    line: loc.line,
    column: loc.column,
  }
}

///|
fn elaborate_nodes_with_gaps(
  xs : ArrayView[S],
  gaps : Array[AppGap],
  start_gap_index : Int,
) -> Array[Term] raise {
  let result = []
  for i in 0..<xs.length() {
    if i > 0 {
      let gap_index = start_gap_index + i - 1
      if gap_index < gaps.length() && gaps[gap_index] == Space {
        result.push(Term::Text(" ", gap_separator_loc(xs[i])))
      }
    }
    result.push(Stage2::elaborate_node(xs[i]))
  }
  result
}

///|
fn elaborate_template(xs : ArrayView[S], app_loc : SourceLoc) -> Term raise {
  if xs.length() < 2 {
    raise Stage2Error::TemplateRequiresNameAndParamList(
      items=erase_nodes(xs),
      loc=Some(app_loc),
    )
  }
  let name = elaborate_name(xs[0])
  let (params, param_defaults) = match xs[1] {
    App(list, _, _) => {
      let names : Array[Name] = []
      let defaults : Array[(Name, Array[Term])] = []
      for param_node in list {
        let (name, default_value) = elaborate_param_spec(param_node)
        names.push(name)
        match default_value {
          Some(value) => defaults.push((name, value))
          None => ()
        }
      }
      (names, defaults)
    }
    _ =>
      raise Stage2Error::TemplateParamsMustBeList(
        found=xs[1],
        loc=Some(xs[1].loc()),
      )
  }
  let body = elaborate_nodes(xs[2:])
  TemplateDefinition(name, params, param_defaults, body, app_loc)
}

///|
fn elaborate_app(node : S) -> Term raise {
  match node {
    App(view, gaps, app_loc) =>
      match view {
        [] => Text("", app_loc)
        [f, .. xs] =>
          match elaborate_name(f) {
            "%" => Comment(elaborate_comment(xs), app_loc)
            "_" => Splice(elaborate_nodes_with_gaps(xs, gaps, 1), app_loc)
            "~" => {
              let body = elaborate_nodes_with_gaps(xs, gaps, 1)
              Splice([Text(" ", app_loc), ..body, Text(" ", app_loc)], app_loc)
            }
            "λ" => elaborate_template(xs, app_loc)
            s => App(s, elaborate_nodes_with_gaps(xs, gaps, 1), app_loc)
          }
      }
    _ =>
      raise Stage2Error::InternalInvariantViolation(
        context="elaborate_app expects an App node",
        loc=Some(node.loc()),
      )
  }
}

///|
pub fn Stage2::elaborate_node(node : S) -> Term raise {
  match node {
    Text(s, loc) => Text(s, loc)
    QuoteBlock(s, loc) => Text(s, loc) // raw block -> text
    QuoteInline(s, loc) => Text(s, loc) // inline raw -> text
    App(_, _, _) => elaborate_app(node)
  }
}

///|
pub fn Stage2::pass(nodes : Array[S]) -> Array[Term] raise {
  let result = []
  for node in nodes {
    result.push(Stage2::elaborate_node(node))
  }
  result
}
