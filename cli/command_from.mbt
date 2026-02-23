///|
fn run_from_command(input_path : String) -> Unit {
  if !input_path.has_suffix(".md") {
    println("error: input file must have .md suffix: \{input_path}")
    return
  }

  guard read_input(input_path) is Some(source) else { return }
  let altsia = try {
    Some(
      @markdown.KoMarkdown::to_altsia(source, normalize=true, options={
        convert_katex: AppWhenHasParens,
      }),
    )
  } catch {
    e => {
      println("error while converting \{input_path}: \{e}")
      None
    }
  }
  guard altsia is Some(altsia) else { return }
  let output_path = default_output_path(input_path)
  if write_output(output_path, altsia) {
    println("done: \{output_path}")
  }
}
