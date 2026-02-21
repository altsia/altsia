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
pub let empty_extern_api : ExternApi = ExternApi::{
  read: x => x,
  katex_render: x => x,
  katex_display_render: x => x,
}

///|
pub fn ExternApi::to_rewriter(api : ExternApi) -> AppRewriter {
  (name, args, loc) => {
    match name {
      "read" => {
        guard args.get(0) is Some(Text(path, _)) else {
          [Text("[Error]: \{args} should be [path: text]", loc)]
        }
        [Text((api.read)(path), loc)]
      }
      // katex render
      "k" => {
        guard args.get(0) is Some(Text(path, _)) else {
          [Text("[Error]: \{args} should be [tex: text]", loc)]
        }
        [Text((api.katex_render)(path), loc)]
      }
      // katex display render
      "kd" => {
        guard args.get(0) is Some(Text(path, _)) else {
          [Text("[Error]: \{args} should be [tex: text]", loc)]
        }
        [Text((api.katex_display_render)(path), loc)]
      }
      _ => [Term::App(name, args, loc)]
    }
  }
}
