///|
async fn main {
  let command = @argparse.Command(
    "obsmark",
    about="Render markdown documents anywhere. ",
    flags=[
      @argparse.FlagArg(
        "ascii",
        about="Render text tables with ASCII line style.",
        short='a',
      ),
      @argparse.FlagArg(
        "ansi",
        about="Render plain text with ANSI escape codes.",
      ),
      @argparse.FlagArg(
        "watch",
        about="Watch the input file and re-render on changes.",
        short='w',
      ),
      @argparse.FlagArg(
        "disable-math",
        about="Do not render math; keep $...$ and $$...$$ as-is.",
      ),
      @argparse.FlagArg(
        "cmark",
        about="Render with the cmark (CommonMark) parser instead of notiz.",
        short='c',
      ),
      @argparse.FlagArg(
        "halfwidth",
        about="Replace full-width punctuation with half-width in text (not in code or math).",
      ),
    ],
    options=[
      OptionArg("output", about="Output file path.", short='o'),
      OptionArg(
        "target",
        about="Output format (\{@notiz.CompileTarget::names().join("|")}).",
        short='t',
        default_values=["text"],
      ),
      OptionArg(
        "range",
        about="Only render the source lines in the given range.",
        short='r',
      ),
    ],
    positionals=[
      PositionArg(
        "input",
        about="Path to the .md input file.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )

  let matches = command.parse()
  guard matches.values.get("input") is Some([input_path]) else {
    return println(command.render_help())
  }
  let input_path = normalize_path(input_path)

  let target = {
    guard matches.values.get("target") is Some([value]) else { @notiz.Text }
    match @notiz.CompileTarget::from_string(value) {
      Ok(target) => target
      Err(error) => return println("error: \{error}")
    }
  }
  let line_style = {
    guard matches.flags.get("ascii") is Some(true) else {
      @backend.LineStyle::Unicode
    }
    @backend.LineStyle::Ascii
  }
  let ansi = matches.flags.get("ansi") is Some(true)
  let disable_math = matches.flags.get("disable-math") is Some(true)
  let use_cmark = matches.flags.get("cmark") is Some(true)
  let halfwidth_punct = matches.flags.get("halfwidth") is Some(true)
  if use_cmark {
    match matches.values.get("target") {
      Some(["html"]) | Some(["html-text"]) =>
        return println(
          "error: --cmark only renders terminal text; --target html/html-text is not available with cmark yet",
        )
      _ => ()
    }
  }
  let options = RenderOptions::{
    target,
    ansi,
    line_style,
    disable_math,
    use_cmark,
    output_path: matches.values
    .get("output")
    .map_or(None, values => Some(values[0])),
    range: {
      guard matches.values.get("range") is Some([value]) else { None }
      let parsed = parse_range(value) catch {
        error => return println("error: invalid --range \{value}: \{error}")
      }
      Some(parsed)
    },
    halfwidth_punct,
  }

  if matches.flags.get("watch") is Some(true) {
    watch_and_render(input_path, options)
  } else {
    render_input(input_path, options)
  }
}
