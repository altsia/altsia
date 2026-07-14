///|
async fn main {
  let cmd = @argparse.Command(
    "tim",
    about="Compile an .alt file to HTML.",
    flags=[
      @argparse.FlagArg(
        "watch",
        short='w',
        long="watch",
        about="Watch the input file and recompile on changes.",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "input",
        about="Path to the .alt file.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
  let matches = cmd.parse() catch { err => return println(err) }
  guard matches.values.get("input") is Some([input_path]) else {
    return println(cmd.render_help())
  }

  if !input_path.has_suffix(".alt") {
    return println("error: input path must end with .alt")
  }

  let output_path = output_path_for(input_path)
  if matches.flags.get("watch") is Some(true) {
    watch_and_compile(input_path, output_path)
  } else {
    compile_file(input_path, output_path)
  }
}

///|
fn compile_file(input_path : String, output_path : String) -> Unit {
  guard read_input(input_path) is Some(source) &&
    render_html(input_path, source) is Some(html) &&
    write_output(output_path, html) else {
    return
  }
  println("output: \{output_path}")
}

///|
async fn watch_and_compile(input_path : String, output_path : String) -> Unit {
  let input_name = input_filename(input_path)
  let watcher = @async_fs.Watcher(watch_directory(input_path), ignored_paths=path => {
    path != input_name
  }) catch {
    error => return println("error: unable to watch \{input_path}: \{error}")
  }
  defer watcher.close()
  compile_file(input_path, output_path)
  println("watching: \{input_path}")
  for ;; {
    watcher.wait_any() catch {
      error => return println("error: stopped watching \{input_path}: \{error}")
    }
    compile_file(input_path, output_path)
  }
}

///|
fn output_path_for(input_path : String) -> String {
  let end = input_path.length() - 4
  input_path.unsafe_substring(start=0, end~) + ".html"
}

///|
fn render_html(input_path : String, source : String) -> String? {
  let options = Some({
    ..@backend_html.HtmlDocumentOptions::default(),
    extensions: [html_include_resolver(input_dir(input_path))],
  })
  try @backend_html.to_html_document(source, options) catch {
    error => {
      println(error.render())
      None
    }
  } noraise {
    html => Some(html)
  }
}

///|
fn html_include_resolver(base_dir : String) -> @backend_html.ElementResolver {
  compiler => {
    guard compiler.call.tag == "html.include" else { return None }
    let path = include_path(compiler.call, compiler.context)
    let resolved = resolve_include_path(base_dir, path)
    let content = read_include(resolved, compiler.call.span)
    let raw = @sexp.SexpNode::RawHtml(content)
    Some(@backend_html.ElementOutput::body([raw]))
  }
}

///|
fn include_path(
  call : @backend_html.ElementCall,
  context : @backend_html.CompileContext,
) -> String raise @core.Diagnostic {
  for attr in call.attrs {
    if attr.name != "src" {
      continue
    }
    guard attr.value is Some(value) else {
      raise attr.span.diagnostic(
        @core.DiagnosticPhase::Type,
        "html.include src requires a value",
      )
    }
    return value.to_scalar(context.env)
  }
  guard !call.children.is_empty() else {
    raise call.span.diagnostic(
      @core.DiagnosticPhase::Type,
      "html.include requires a path",
    )
  }
  @core.nodes_to_value(call.children).to_scalar(context.env)
}

///|
fn read_include(
  path : String,
  span : @core.SourceSpan,
) -> String raise @core.Diagnostic {
  @fs.read_file_to_string(path) catch {
    @fs.IOError(msg) =>
      raise span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        describe_io_error("including", path, msg),
      )
  }
}

///|
fn resolve_include_path(base_dir : String, path : String) -> String {
  if path.has_prefix("/") || base_dir.is_empty() {
    return path
  }
  base_dir + path
}

///|
fn input_dir(path : String) -> String {
  let chars = path.to_array()
  let mut index = chars.length()
  while index > 0 {
    index -= 1
    if is_path_separator(chars[index]) {
      return path.unsafe_substring(start=0, end=index + 1)
    }
  }
  ""
}

///|
fn input_filename(path : String) -> String {
  let dir = input_dir(path)
  path.unsafe_substring(start=dir.length(), end=path.length())
}

///|
fn watch_directory(path : String) -> String {
  let dir = input_dir(path)
  guard !dir.is_empty() else { dir }
  "."
}

///|
fn is_path_separator(ch : Char) -> Bool {
  ch == '/' || ch == '\\'
}

///|
fn read_input(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    @fs.IOError(msg) => {
      println(describe_io_error("reading", path, msg))
      None
    }
  }
}

///|
fn write_output(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    @fs.IOError(msg) => {
      println(describe_io_error("writing", path, msg))
      false
    }
  }
}
