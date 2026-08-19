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

  guard input_path.has_suffix(".alt") else {
    return println("error: input path must end with .alt")
  }

  let output_path = output_path_for(input_path)
  match matches.flags.get("watch") {
    Some(true) => watch_and_compile(input_path, output_path)
    _ =>
      compile_file(input_path, output_path) catch {
        err => println("error: \{err}")
      }
  }
}

///|
async fn compile_file(input_path : String, output_path : String) -> Unit {
  let source = @async_fs.read_file(input_path).text()
  guard render_html(input_path, source) is Some(html) else { return }
  @async_fs.write_file(output_path, html)
  println("output: \{output_path}")
}

///|
async fn watch_and_compile(input_path : String, output_path : String) -> Unit {
  let input_name = @path.Path(input_path).basename().to_owned()
  let watcher = @async_fs.Watcher(watch_directory(input_path), ignored_paths=path => {
    path != input_name
  }) catch {
    error => return println("error: unable to watch \{input_path}: \{error}")
  }
  defer watcher.close()
  compile_file(input_path, output_path) catch {
    err => println("error: \{err}")
  }
  println("watching: \{input_path}")
  for ;; {
    watcher.wait_any() catch {
      error => return println("error: stopped watching \{input_path}: \{error}")
    }
    compile_file(input_path, output_path) catch {
      err => println("error: \{err}")
    }
  }
}

///|
fn output_path_for(input_path : String) -> String {
  let end = input_path.length() - 4
  input_path.unsafe_substring(start=0, end~) + ".html"
}

///|
async fn render_html(input_path : String, source : String) -> String? {
  let base_dir = @path.Path(input_path).dirname().to_string()
  let contents : Map[String, String] = Map([])
  for target in collect_include_targets(source, base_dir) {
    let (path, span) = target
    let content = read_include(path, span) catch {
      error => {
        println(error.render())
        return None
      }
    }
    contents[path] = content
  }
  let options = Some({
    ..@backend_html.HtmlDocumentOptions::default(),
    extensions: [html_include_resolver(base_dir, contents)],
  })
  Some(@backend_html.to_html_document(source, options)) catch {
    error => {
      println(error.render())
      None
    }
  }
}

///|
fn collect_include_targets(
  source : String,
  base_dir : String,
) -> Array[(String, @core.SourceSpan)] {
  let targets : Array[(String, @core.SourceSpan)] = []
  let options = Some({
    ..@backend_html.HtmlDocumentOptions::default(),
    extensions: [
      compiler => {
        guard compiler.call.tag == "html.include" else { return None }
        let path = include_path(compiler.call, compiler.context)
        targets.push((resolve_include_path(base_dir, path), compiler.call.span))
        Some(@backend_html.ElementOutput::body([]))
      },
    ],
  })
  ignore(@backend_html.to_html_document(source, options) catch { _ => "" })
  targets
}

///|
fn html_include_resolver(
  base_dir : String,
  contents : Map[String, String],
) -> @backend_html.ElementResolver {
  compiler => {
    guard compiler.call.tag == "html.include" else { return None }
    let path = include_path(compiler.call, compiler.context)
    let resolved = resolve_include_path(base_dir, path)
    guard contents.get(resolved) is Some(content) else {
      raise compiler.call.span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        "html.include target was not preloaded: " + resolved,
      )
    }
    let raw = @sexp.SexpNode::Raw(content)
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
async fn read_include(
  path : String,
  span : @core.SourceSpan,
) -> String raise @core.Diagnostic {
  @async_fs.read_file(path).text() catch {
    err =>
      raise span.diagnostic(
        @core.DiagnosticPhase::ContentModel,
        describe_io_error("including", path, err.to_string()),
      )
  }
}

///|
fn resolve_include_path(base_dir : String, path : String) -> String {
  if path.has_prefix("/") || base_dir.is_empty() {
    return path
  }
  @path.Path::join(base_dir, path).normalize().to_string()
}

///|
fn watch_directory(path : String) -> String {
  let dir = @path.Path(path).dirname().to_string()
  guard dir.is_empty() else { dir }
  "."
}
