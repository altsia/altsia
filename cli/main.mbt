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
    [_, COMMAND_FROM]
    | [_, COMMAND_FROM, "-h"]
    | [_, COMMAND_FROM, "--help"]
    | [_, "help", COMMAND_FROM] => usage_from()
    [_, COMMAND_FROM, input_path] => run_from_command(input_path)
    [_, COMMAND_FROM, ..] =>
      println("error: too many arguments for command '\{COMMAND_FROM}'")
    [_, "help"] | [_, "-h"] | [_, "--help"] | [_] => usage_root()
    [_, "help", .. topic] => println("unknown command: help " + topic.join(" "))
    [_, .. cmd] => println("unknown command: " + cmd.join(" "))
    [] => println("(empty env)")
  }
}
