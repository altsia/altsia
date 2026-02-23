///|
fn usage() -> Unit {
  println("usage: altsia from <input.md>")
}

///|
fn default_output_path(input_path : String) -> String {
  let stem = input_path.unsafe_substring(start=0, end=input_path.length() - 3)
  stem + ".alt"
}

///|
fn main {
  let args = @env.args()

  match args {
    [_, "from", input_path] => run_from_command(input_path)
    [_, "from"] => usage()
    [_, cmd] => {
      println("unknown command: \{cmd}")
      usage()
    }
    [] => usage()
    _ => {
      println("invalid arguments")
      usage()
    }
  }
}
