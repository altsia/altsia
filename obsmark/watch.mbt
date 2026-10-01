///|
async fn watch_and_render(input_path : String, options : RenderOptions) -> Unit {
  let input_name = input_path.unsafe_substring(
    start=input_path.rev_find("/").map_or(0, i => i + 1),
    end=input_path.length(),
  )

  let watched_dir = input_path
    .rev_find("/")
    .map_or(".", i => input_path.unsafe_substring(start=0, end=i + 1))

  let ignored_paths = path => path != input_name
  let watcher = @fs.Watcher(watched_dir, ignored_paths~) catch {
    error => return println("error: unable to watch \{input_path}: \{error}")
  }
  defer watcher.close()

  render_input(input_path, options)
  println("watching: \{input_path} (Ctrl-C to stop)")
  for ;; {
    watcher.wait_any() catch {
      error if @async.is_cancellation_error(error) => return
      error => return println("error: stopped watching \{input_path}: \{error}")
    }
    guard options.output_path is Some(_) else { println("\u001b[2J\u001b[H") }
    render_input(input_path, options)
  }
}
