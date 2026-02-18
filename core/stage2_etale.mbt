///|
pub type Stage2Etale

///|
pub(all) suberror Stage2EtaleError {
  TemplateArityMismatch(
    template_name~ : Name,
    expected~ : Int,
    got~ : Int,
    args~ : Array[Term],
    loc~ : SourceLoc?
  )
  NestedTemplateDefinitionInSubstitution(term~ : Term, loc~ : SourceLoc?)
  UnexpectedTemplateDefinitionInExpand(term~ : Term, loc~ : SourceLoc?)
} derive(Eq, Show)

///|
pub struct Template {
  params : Array[Name]
  body : Array[Term]
}

///|
pub type Env = @hashmap.HashMap[Name, Template]

///|
pub type ParamsEnv = @hashmap.HashMap[Name, Array[Term]]

///|
pub struct LocatedTemplate {
  params : Array[Name]
  body : Array[LocatedTerm]
}

///|
pub type LocatedEnv = @hashmap.HashMap[Name, LocatedTemplate]

///|
pub type LocatedParamsEnv = @hashmap.HashMap[Name, Array[LocatedTerm]]
