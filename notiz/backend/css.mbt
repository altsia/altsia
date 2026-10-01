///|
/// Declarative CSS construction. `css_props` renders an inline style value,
/// `css_rule` a single rule, and `css_media` a media block — no hand-built
/// CSS strings.
pub fn css_props(props : Array[(String, String)]) -> String {
  props.map(p => "\{css_escape(p.0)}: \{css_escape(p.1)}").join("; ")
}

///|
/// `selector { prop: value; ... }`, one declaration per line, indented.
pub fn css_rule(selector : String, props : Array[(String, String)]) -> String {
  let body = props
    .map(p => "  \{css_escape(p.0)}: \{css_escape(p.1)};")
    .join("\n")
  "\{css_escape(selector)} {\n\{body}\n}"
}

///|
/// `@media condition { ... }`, indenting every line of `rules`.
pub fn css_media(condition : String, rules : Array[String]) -> String {
  let body = rules.join("\n").split("\n").map(line => "  \{line}").join("\n")
  "@media \{css_escape(condition)} {\n\{body}\n}"
}

///|
/// `@name { prop: value; ... }`, a declaration block under an at-rule such as
/// `@page`, `@font-face`, or `@keyframes`. `name` is the identifier after
/// `@`, e.g. `page :first` or `font-face`.
pub fn css_at_block(name : String, props : Array[(String, String)]) -> String {
  let body = props
    .map(p => "  \{css_escape(p.0)}: \{css_escape(p.1)};")
    .join("\n")
  "@\{css_escape(name)} {\n\{body}\n}"
}

///|
/// Escapes characters that would break out of a CSS declaration or rule:
/// backslash, `;`, `{`, `}`, `"`, and newlines (dropped).
fn css_escape(s : String) -> String {
  s
  .replace_all(old="\\", new="\\\\")
  .replace_all(old=";", new="\\;")
  .replace_all(old="{", new="\\{")
  .replace_all(old="}", new="\\}")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="")
  .replace_all(old="\r", new="")
}
