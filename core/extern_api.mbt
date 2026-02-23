///|
pub(all) struct ExternApi {
  /// (read ...)
  read : (String) -> String
  /// (k ...)
  katex_render : (String) -> String
  /// (kd ...)
  katex_display_render : (String) -> String
}

///|
pub(all) suberror IncludeError {
  InvalidIncludeArguments(args~ : Array[Term], loc~ : SourceLoc)
  IncludeExpansionFailed(path~ : String, source~ : String, cause~ : Error)
}

///|
pub(all) suberror ExternApiError {
  InvalidExternArguments(
    app_name~ : Name,
    expected~ : String,
    args~ : Array[Term],
    loc~ : SourceLoc
  )
}

///|
const EXTERN_RESULT_APP_NAME : Name = "extern result"

///|
pub fn is_extern(name : Name) -> Bool {
  name == EXTERN_RESULT_APP_NAME
}

///|
fn extern_term(content : String, loc : SourceLoc) -> Term {
  App(EXTERN_RESULT_APP_NAME, [Text(content, loc)], loc)
}

///|
fn extern_first_text_arg(args : Array[Term]) -> String? {
  match args.get(0) {
    Some(Text(value, _)) => Some(value)
    _ => None
  }
}

///|
fn extern_require_first_text_arg(
  app_name : Name,
  expected : String,
  args : Array[Term],
  loc : SourceLoc,
) -> String raise {
  match extern_first_text_arg(args) {
    Some(value) => value
    None =>
      raise ExternApiError::InvalidExternArguments(
        app_name~,
        expected~,
        args~,
        loc~,
      )
  }
}

///|
fn include_path_arg(args : Array[Term], loc : SourceLoc) -> String raise {
  match args.get(0) {
    Some(Text(path, _)) => path
    _ => raise IncludeError::InvalidIncludeArguments(args~, loc~)
  }
}

///|
fn include_expand(
  api : ExternApi,
  path : String,
  source : String,
) -> Array[Term] raise {
  try
    source
    |> Stage1::parse
    |> Stage2::pass
    |> Stage2Etale::expand_program
    |> Stage2Extern::rewrite_apps_raise(api.to_rewriter_raise())
  catch {
    err => raise IncludeError::IncludeExpansionFailed(path~, source~, cause=err)
  }
}

///|
pub fn ExternApi::to_rewriter_raise(api : ExternApi) -> AppRewriterRaise {
  (name, args, loc) => {
    match name {
      "include" => {
        let path = include_path_arg(args, loc)
        include_expand(api, path, (api.read)(path))
      }
      "read" => {
        let path = extern_require_first_text_arg(
          "read", "[path: text]", args, loc,
        )
        [extern_term((api.read)(path), loc)]
      }
      // katex render
      "k" => {
        let raw_tex = extern_require_first_text_arg(
          "k", "[tex: text]", args, loc,
        )
        [extern_term((api.katex_render)(raw_tex), loc)]
      }
      // katex display render
      "kd" => {
        let raw_tex = extern_require_first_text_arg(
          "kd", "[tex: text]", args, loc,
        )
        [extern_term((api.katex_display_render)(raw_tex), loc)]
      }
      _ => [Term::App(name, args, loc)]
    }
  }
}
