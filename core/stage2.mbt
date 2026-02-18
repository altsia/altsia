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
  TemplateParamApplicationMissingHead(found~ : S, loc~ : SourceLoc?)
  InternalInvariantViolation(context~ : String, loc~ : SourceLoc?)
} derive(Eq, Show)
