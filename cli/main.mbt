///|
fn usage_root() -> Unit {
  let text =
    $|altsia 0.1.5
    $|
    $|Altsia command-line tools.
    $|
    $|USAGE:
    $|  altsia <COMMAND>
    $|  altsia --help
    $|
    $|COMMANDS:
    $|  \{COMMAND_FROM}      Convert one Markdown file into one .alt file
    $|  \{COMMAND_TO}        Convert one .alt file into one .html file
    $|  help      Print this message or the help of a subcommand
    $|
    $|OPTIONS:
    $|  -h, --help    Print help information
    $|
  println(text)
}

///|
fn main {
  let args = @env.args()
  match args {
    // from
    [_, COMMAND_FROM]
    | [_, COMMAND_FROM, "-h"]
    | [_, COMMAND_FROM, "--help"]
    | [_, "help", COMMAND_FROM] => usage_from()
    [_, COMMAND_FROM, input_path] => run_from_command(input_path)
    [_, COMMAND_FROM, ..] =>
      println("error: too many arguments for command '\{COMMAND_FROM}'")
    // to
    [_, COMMAND_TO]
    | [_, COMMAND_TO, "-h"]
    | [_, COMMAND_TO, "--help"]
    | [_, "help", COMMAND_TO] => usage_to()
    [_, COMMAND_TO, input_path] => run_to_command(input_path)
    [_, COMMAND_TO, ..] =>
      println("error: too many arguments for command '\{COMMAND_TO}'")

    [_, "help"] | [_, "-h"] | [_, "--help"] | [_] => usage_root()
    [_, "help", .. topic] => println("unknown command: help " + topic.join(" "))
    [_, .. cmd] => println("unknown command: " + cmd.join(" "))
    [] => println("(empty env)")
  }
}
