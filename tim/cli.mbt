///|
fn main {
  let cmd = @argparse.Command("tim", about="Compile an .alt file to HTML.", positionals=[
    @argparse.PositionArg(
      "input",
      about="Path to the .alt file.",
      num_args=@argparse.ValueRange::single(),
    ),
  ])
  let matches = cmd.parse() catch { err => return println(err) }
  guard matches.values.get("input") is Some([input_path]) else {
    return println(cmd.render_help())
  }

  if !input_path.has_suffix(".alt") {
    return println("error: input path must end with .alt")
  }

  let output_path = output_path_for(input_path)
  guard read_input(input_path) is Some(source) &&
    render_html(input_path, source) is Some(html) &&
    write_output(output_path, html) else {
    return
  }
  return println("output: \{output_path}")
}

///|
fn output_path_for(input_path : String) -> String {
  let end = input_path.length() - 4
  input_path.unsafe_substring(start=0, end~) + ".html"
}

///|
fn render_html(input_path : String, source : String) -> String? {
  let options = {
    ..@backend_html.HtmlDocumentOptions::default(),
    extensions: [html_include_resolver(input_dir(input_path))],
  }
  let result = @backend_html.to_html_document(source, options~)
  if result is Err(error) {
    return {
      println(error.render())
      None
    }
  }
  guard result is Ok(html) else { return None }
  Some(html)
}

///|
fn html_include_resolver(base_dir : String) -> @backend_html.ElementResolver {
  (call, context) => {
    if call.tag != "html.include" {
      return Ok(None)
    }
    include_path(call, context).bind(path => {
      let resolved = resolve_include_path(base_dir, path)
      read_include(resolved, call.span).map(content => {
        let raw = @sexp.SexpNode::RawHtml(content)
        Some(@backend_html.ElementOutput::body([raw]))
      })
    })
  }
}

///|
fn include_path(
  call : @backend_html.ElementCall,
  context : @backend_html.CompileContext,
) -> Result[String, @core.Diagnostic] {
  for attr in call.attrs {
    if attr.name != "src" {
      continue
    }
    guard attr.value is Some(value) else {
      return Err(
        attr.span.diagnostic(
          @core.DiagnosticPhase::Type,
          "html.include src requires a value",
        ),
      )
    }
    return @core.value_to_scalar(value, context.env)
  }
  guard !call.children.is_empty() else {
    return Err(
      call.span.diagnostic(
        @core.DiagnosticPhase::Type,
        "html.include requires a path",
      ),
    )
  }
  @core.value_to_scalar(@core.nodes_to_value(call.children), context.env)
}

///|
fn read_include(
  path : String,
  span : @core.SourceSpan,
) -> Result[String, @core.Diagnostic] {
  Ok(@fs.read_file_to_string(path)) catch {
    @fs.IOError(msg) =>
      Err(
        span.diagnostic(
          @core.DiagnosticPhase::ContentModel,
          describe_io_error("including", path, msg),
        ),
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
    if chars[index] == '/' {
      return path.unsafe_substring(start=0, end=index + 1)
    }
  }
  ""
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

///|
fn describe_io_error(action : String, path : String, msg : String) -> String {
  match () {
    _ if is_file_not_found_error(msg) =>
      "I/O error while \{action}: file not found: \{path}"
    _ if is_permission_error(msg) =>
      "I/O error while \{action}: permission denied: \{path}"
    _ if is_directory_error(msg) =>
      "I/O error while \{action}: expected a file path: \{path}"
    _ => "I/O error while \{action} \{path}: \{msg}"
  }
}

///|
fn is_file_not_found_error(msg : String) -> Bool {
  msg.contains("No such file") ||
  msg.contains("cannot find") ||
  msg.contains("not found")
}

///|
fn is_permission_error(msg : String) -> Bool {
  msg.contains("Permission denied") ||
  msg.contains("Access is denied") ||
  msg.contains("access is denied")
}

///|
fn is_directory_error(msg : String) -> Bool {
  msg.contains("Is a directory") || msg.contains("is a directory")
}
