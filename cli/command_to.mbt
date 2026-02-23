///|
const COMMAND_TO : String = "to"

///|
fn run_to_command(input_path : String) -> Unit {
  if !input_path.has_suffix(".alt") {
    println("error: input file must have .alt suffix: \{input_path}")
    return
  }

  guard read_input(input_path) is Some(source) else { return }

  let result = @altsia.altsia_to_html_with_rewriter_result(
    source,
    text => text,
    extern_api={
      read: path => read_relative_input(input_path, path).unwrap_or(""),
      katex_render: tex => "$\{tex}$",
      katex_display_render: tex => "\n\n$$\{tex}$$\n\n",
    },
  )

  match result {
    Err(errors) => println(errors.join("\n"))
    Ok(html) => {
      let output_path = default_output_path(
        input_path,
        origin_suffix=".alt",
        target_suffix=".html",
      )
      if write_output(output_path, html) {
        println("done: \{output_path}")
      }
    }
  }
}
