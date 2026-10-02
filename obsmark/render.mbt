///|
/// Everything needed to render one input file, shared by the one-shot and
/// watch paths.
struct RenderOptions {
  target : @notiz.CompileTarget
  ansi : Bool
  line_style : @backend.LineStyle
  disable_math : Bool
  use_cmark : Bool
  output_path : String?
  range : (Int, Int)?
  halfwidth_punct : Bool
}

///|
async fn render_input(input_path : String, options : RenderOptions) -> Unit {
  let source = read_source(input_path, range=options.range) catch {
    e => return println("error reading file \{input_path}: \{e}")
  }
  let output = if options.use_cmark {
    @notiz.compile_cmark(
      source,
      cmark_options(),
      line_style=options.line_style,
      ansi=options.ansi,
      disable_math=options.disable_math,
      halfwidth_punct=options.halfwidth_punct,
    )
  } else {
    @notiz.compile(
      source,
      target=options.target,
      ansi=options.ansi,
      line_style=options.line_style,
      disable_math=options.disable_math,
      halfwidth_punct=options.halfwidth_punct,
    ) catch {
      error => return println(@parsing.format_parse_error(error, source))
    }
  }
  guard options.output_path is Some(path) else { return println(output) }
  @fs.write_file(path, output, create_mode=@fs.CreateMode::CreateOrTruncate)
}

///|
/// Reads the whole file at once, narrowing to `range` when given.
///
/// We deliberately avoid `@io.Reader::read_until` line-by-line reading.
/// Line-at-a-time reading pays a fixed cost per line — one async call, a
/// separator encode, and a `String` allocation, even for lines that are only
/// skipped — to save memory, and that trade only wins on 100MB+ inputs.
/// Markdown never realistically gets there: 1MB of source already renders to
/// a few hundred A4 pages and 10MB is encyclopedic. At those sizes reading
/// the whole file and letting `extract_range` lazily materialize only the
/// selected lines is both faster and still O(range) in memory, so this is
/// the optimal strategy given the input sizes obsmark actually handles.
async fn read_source(input_path : String, range~ : (Int, Int)?) -> String {
  let content = @fs.read_file(input_path).text()
  guard range is Some((start, end)) else { return content }
  extract_range(content, start, end).join("\n")
}

///|
/// Options for cmark rendering: the full CommonMark plus extension set.
fn cmark_options() -> @cmark.Options {
  let options = @cmark.Options::empty()
  [
    @cmark.enable_tables(),
    @cmark.enable_footnotes(),
    @cmark.enable_strikethrough(),
    @cmark.enable_tasklists(),
    @cmark.enable_heading_attributes(),
    @cmark.enable_yaml_style_metadata_blocks(),
    @cmark.enable_pluses_delimited_metadata_blocks(),
    @cmark.enable_math(),
    @cmark.enable_math_everywhere(),
    @cmark.enable_gfm(),
    @cmark.enable_definition_list(),
    @cmark.enable_superscript(),
    @cmark.enable_subscript(),
    @cmark.enable_wikilinks(),
    @cmark.enable_container_extensions(),
    @cmark.enable_highlight(),
    @cmark.enable_cjk_friendly_emphasis(),
  ].each(flag => options.insert(flag))
  options
}

///|
fn normalize_path(path : String) -> String {
  path.replace_all(old="\\", new="/")
}
