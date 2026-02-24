// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
const COMMAND_FROM : String = "from"

///|
fn usage_from() -> Unit {
  let text =
    $|
    $|Convert one Markdown file into one .alt file.
    $|
    $|USAGE:
    $|  altsia \{COMMAND_FROM} <INPUT.md>
    $|  altsia \{COMMAND_FROM} --help
    $|
    $|ARGS:
    $|  <INPUT.md>    Input Markdown file path (must end with .md)
    $|
    $|OPTIONS:
    $|  -h, --help    Print help information
    $|
    $|OUTPUT:
    $|  Writes output next to input with same stem and .alt suffix.
    $|  Example: notes/a.md -> notes/a.alt
    $|
    $|EXAMPLES:
    $|  altsia \{COMMAND_FROM} notes/intro.md
    $|  altsia \{COMMAND_FROM} --help
  println(text)
}

///|
fn run_from_command(input_path : String) -> Unit {
  if !input_path.has_suffix(".md") {
    println("error: input file must have .md suffix: \{input_path}")
    return
  }

  guard read_input(input_path) is Some(source) else { return }
  let options = @markdown.MarkdownConvertOptions::{
    convert_katex: AppWhenHasParens,
  }
  let altsia = Some(@markdown.KoMarkdown::to_altsia(source, options~)) catch {
    e => {
      println("error while converting \{input_path}: \{e}")
      None
    }
  }
  guard altsia is Some(altsia) else { return }
  let output_path = default_output_path(
    input_path,
    origin_suffix=".md",
    target_suffix=".alt",
  )
  if write_output(output_path, altsia) {
    println("done: \{output_path}")
  }
}
