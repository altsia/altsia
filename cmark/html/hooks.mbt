///|
/// The Markdown delimiter form. `Display` (`$$`) can still occur inside a
/// paragraph; a math hook replaces the math event, not its parent.
pub(all) enum MathKind {
  Inline
  Display
}

///|
pub(all) enum RawHtmlKind {
  Inline
  Block
}

///|
/// The code block body before HTML escaping, without its fences.
pub type CodeBlockSource = String

///|
pub struct Hooks {
  math : ((String, MathKind) -> String?)?
  code_block : ((CodeBlockSource, @cmark.CodeBlockInfo) -> String?)?
  raw_html : ((String, RawHtmlKind) -> String?)?
}

///|
/// Each hook gets the unescaped event text. `Some(html)` is inserted verbatim
/// instead of the node's built-in markup; `None` uses the built-in rendering.
/// The block hooks run once per block.
pub fn Hooks::new(
  math? : (String, MathKind) -> String?,
  code_block? : (CodeBlockSource, @cmark.CodeBlockInfo) -> String?,
  raw_html? : (String, RawHtmlKind) -> String?,
) -> Hooks {
  { math, code_block, raw_html, }
}

///|
fn Hooks::write_math(
  self : Hooks,
  out : StringBuilder,
  source : String,
  kind : MathKind,
) -> Unit {
  if self.math.bind(hook => hook(source, kind)) is Some(html) {
    out.write_string(html)
  } else {
    let delim = if kind is Display { "$$" } else { "$" }
    out.write_string(delim)
    write_escaped(out, source)
    out.write_string(delim)
  }
}

///|
fn Hooks::write_code_block(
  self : Hooks,
  out : StringBuilder,
  source : CodeBlockSource,
  info : @cmark.CodeBlockInfo,
) -> Unit {
  if self.code_block.bind(hook => hook(source, info)) is Some(html) {
    out.write_string(html)
  } else {
    out.write_string("<pre><code")
    let language = StringBuilder()
    language.write_iter(info.iter().take_while(c => !c.is_ascii_whitespace()))
    if !language.is_empty() {
      write_attr(out, "class", "language-\{language}")
    }
    out.write_char('>')
    write_escaped(out, source)
    out.write_string("</code></pre>\n")
  }
}

///|
fn Hooks::write_raw_html(
  self : Hooks,
  out : StringBuilder,
  source : String,
  kind : RawHtmlKind,
) -> Unit {
  out.write_string(
    self.raw_html.bind(hook => hook(source, kind)).unwrap_or(source),
  )
}
