///|
pub fn term_plain_text(term : @core.Term) -> String {
  match term {
    @core.Term::Text(text, _) => text
    @core.Term::App(_, args, _) => terms_plain_text(args)
    @core.Term::Splice(terms, _) => terms_plain_text(terms)
    @core.Term::Comment(_, _) => ""
    @core.Term::TemplateDefinition(_, _, _, body, _) => terms_plain_text(body)
  }
}

///|
pub fn terms_plain_text(values : Array[@core.Term]) -> String {
  values.map(term_plain_text).fold(init="", (s, t) => s + t)
}
