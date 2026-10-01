///|
pub fn compile(
  source : String,
  target? : CompileTarget = Text,
  line_style? : @backend.LineStyle = @backend.LineStyle::Ascii,
  ansi? : Bool = false,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
) -> String raise @parsing.SyntaxError {
  let (frontmatter, blocks) = match
    @parsing.document_with_metadata.parse(source |> @talc.Input::new) {
    Ok(result) => result
    Err(err) => raise @parsing.SyntaxError::of_parse_error(err)
  }
  let frontmatter = {
    ..frontmatter,
    builtin: {
      ..frontmatter.builtin,
      title: @backend.page_title(frontmatter, blocks),
    },
  }
  let paper = frontmatter.builtin.paper

  match target {
    Html =>
      @backend.render_document_page(
        blocks,
        frontmatter,
        paper~,
        target=@backend.Mathml,
        disable_math~,
        halfwidth_punct~,
      )
    HtmlKaTeX =>
      @backend.render_document_page(
        blocks,
        frontmatter,
        paper~,
        target=@backend.Unicode,
        disable_math=true, // disable_math: true
        halfwidth_punct~,
        head_extra=@backend.HTML_KATEX_RENDER + @backend.HTML_KATEX_FONT_RESIZE,
      )
    HtmlCanonical =>
      @backend.render_document_page(
        blocks,
        frontmatter,
        paper~,
        target=@backend.Canonical,
        disable_math=false,
        halfwidth_punct~,
        head_extra=@backend.HTML_KATEX_RENDER + @backend.HTML_KATEX_FONT_RESIZE,
      )
    HtmlText =>
      @backend.render_page(
        @backend.render_document(
          blocks,
          target=@backend.Unicode,
          disable_math~,
          halfwidth_punct~,
        ),
        frontmatter,
        paper~,
      )
    Text =>
      @backend.render_terminal_document(
        blocks,
        line_style~,
        ansi~,
        disable_math~,
        halfwidth_punct~,
      )
  }
}

///|
/// Compiles `source` with the cmark parser and renders it as terminal text.
///
/// Unlike [`compile`](`compile`), parsing is delegated to the CommonMark-
/// conformant `@cmark` port, so this entry can never fail.
pub fn compile_cmark(
  source : String,
  options : @cmark.Options,
  line_style? : @backend.LineStyle = @backend.LineStyle::Ascii,
  ansi? : Bool = false,
  disable_math? : Bool = false,
  halfwidth_punct? : Bool = false,
) -> String {
  @backend.render_terminal_events(
    @cmark.parse(source, options),
    line_style~,
    ansi~,
    disable_math~,
    halfwidth_punct~,
  )
}

///|
pub(all) enum CompileTarget {
  Text
  Html
  HtmlText
  HtmlKaTeX
  HtmlCanonical
}

///|
fn all_targets() -> ReadOnlyArray[(String, CompileTarget)] {
  [
    ("text", Text),
    ("html", Html),
    ("html-text", HtmlText),
    ("html-katex", HtmlKaTeX),
    ("html-canonical", HtmlCanonical),
  ]
}

///|
pub fn CompileTarget::from_string(
  name : String,
) -> Result[CompileTarget, String] {
  for entry in all_targets() {
    if entry.0 == name {
      return Ok(entry.1)
    }
  }
  Err("unknown target: \{name}")
}

///|
pub fn CompileTarget::names() -> ReadOnlyArray[String] {
  all_targets().map(entry => entry.0)
}
