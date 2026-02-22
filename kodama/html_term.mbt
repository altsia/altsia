///|
/// Build HTML-shaped `@core.Term` directly.
///
/// This keeps everything in Stage2/Stage3 term space and avoids an extra
/// intermediate HTML node model.

///|
/// Build a text term.
#alias(htext)
pub fn html_text_term(content : String, loc : @core.SourceLoc) -> @core.Term {
  @core.Term::Text(content, loc)
}

///|
/// Build a named argument term `(:name ...values)`.
/// `name` accepts either `name` or `:name`.
#alias(hnamed)
pub fn html_named_attr_term(
  name : String,
  values : Array[@core.Term],
  loc : @core.SourceLoc,
) -> @core.Term {
  @core.Term::App(normalize_named_arg_key(name), values, loc)
}

///|
/// Build a string-valued named argument term.
#alias(hattr)
pub fn html_attr(
  name : String,
  value : String,
  loc : @core.SourceLoc,
) -> @core.Term {
  html_named_attr_term(name, [@core.Term::Text(value, loc)], loc)
}

///|
/// Build a class attribute term.
#alias(hclass)
pub fn html_class_attr(
  classes : Array[String],
  loc : @core.SourceLoc,
) -> @core.Term {
  let names = classes.filter(name => !name.is_empty())
  html_attr("class", names.join(" "), loc)
}

///|
/// Convert string-pair attrs into named argument terms.
#alias(hattrs)
pub fn html_attrs_from_pairs(
  attrs : Array[(String, String)],
  loc : @core.SourceLoc,
) -> Array[@core.Term] {
  attrs.map(entry => html_attr(entry.0, entry.1, loc))
}

///|
/// Build an element app term `(tag ...attrs ...children)`.
#alias(hel)
pub fn html_element_term(
  tag : String,
  loc : @core.SourceLoc,
  attrs? : Array[@core.Term] = [],
  children? : Array[@core.Term] = [],
) -> @core.Term {
  let args : Array[@core.Term] = []
  args.append(attrs)
  args.append(children)
  @core.Term::App(tag, args, loc)
}

///|
/// Build an element app term from string-pair attrs.
#alias(help)
pub fn html_element_term_from_pairs(
  tag : String,
  loc : @core.SourceLoc,
  attrs? : Array[(String, String)] = [],
  children? : Array[@core.Term] = [],
) -> @core.Term {
  html_element_term(
    tag,
    loc,
    attrs=html_attrs_from_pairs(attrs, loc),
    children~,
  )
}
