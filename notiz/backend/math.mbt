///|
let global_macros : @katex.Macros = @katex.Macros::make()

///|
pub(all) enum KatexTarget {
  Unicode
  Mathml
  Canonical
}

///|
/// Renders `latex` as Unicode text, MathML, or expanded KaTeX source (macros
/// already expanded); falls back to the raw source when dulox cannot parse it.
fn render_math(
  latex : String,
  display : Bool,
  target~ : KatexTarget,
) -> String raise @katex.ParseFailure {
  let settings = @katex.Settings::make(
    display_mode=display,
    global_group=true,
    macro_store=global_macros,
  )
  let nodes = @eval.parse(latex, settings~, allow_degenerate=false)
  match target {
    Unicode => @unicode.render(nodes)
    Mathml => @mathml.render(nodes)
    Canonical => @canonical.render(nodes)
  }
}
