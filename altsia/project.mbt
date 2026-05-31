///|
priv struct ParsedSource {
  file : SourceFile
  kind : SourceKind
  doc : @core.Document
  module_name : String?
}

///|
fn parse_source_file(
  file : SourceFile,
) -> Result[ParsedSource, @core.Diagnostic] {
  let kind = match source_kind(file.path) {
    Some(value) => value
    None =>
      return Err(
        source_diagnostic(
          file.path,
          Placement,
          "unsupported source file extension: " + file.path,
        ),
      )
  }
  let source_info : @core.SourceInfo = {
    id: Some(file.path),
    line_offset: 0,
    column_offset: 0,
  }
  match @core.parse(file.source, source_info~) {
    Err(error) => Err(error)
    Ok(doc) =>
      Ok({
        file,
        kind,
        doc,
        module_name: match kind {
          Sia => Some(module_name_from_path(file.path))
          Alt => None
        },
      })
  }
}

///|
fn parse_project_sources(
  sources : Array[SourceFile],
) -> Result[Array[ParsedSource], @core.Diagnostic] {
  let parsed : Array[ParsedSource] = []
  for source in sources {
    match parse_source_file(source) {
      Ok(item) => parsed.push(item)
      Err(error) => return Err(error)
    }
  }
  match check_duplicate_modules(parsed) {
    Some(error) => Err(error)
    None => Ok(parsed)
  }
}

///|
fn check_duplicate_modules(parsed : Array[ParsedSource]) -> @core.Diagnostic? {
  let names : Array[(String, String)] = []
  for item in parsed {
    match item.module_name {
      Some(name) => {
        for existing in names {
          let (existing_name, existing_path) = existing
          if existing_name == name {
            return Some(
              source_diagnostic(
                item.file.path,
                Binding,
                "duplicate .sia module name: " + name,
                hint="previous .sia source: " + existing_path,
              ),
            )
          }
        }
        names.push((name, item.file.path))
      }
      None => ()
    }
  }
  None
}

///|
fn find_parsed_source(
  parsed : Array[ParsedSource],
  path : String,
) -> ParsedSource? {
  let normalized = normalize_path(path)
  for item in parsed {
    if normalize_path(item.file.path) == normalized {
      return Some(item)
    }
  }
  None
}

///|
fn find_section_index(sections : Array[UnresolvedSection], id : String) -> Int? {
  for i in 0..<sections.length() {
    if sections[i].id == id {
      return Some(i)
    }
  }
  None
}

///|
fn find_compiled_index(sections : Array[CompiledSection], id : String) -> Int? {
  for i in 0..<sections.length() {
    if sections[i].id == id {
      return Some(i)
    }
  }
  None
}

///|
fn build_import_env(
  current : ParsedSource,
  parsed : Array[ParsedSource],
  builtin_env : @core.CompileEnv,
) -> Result[@core.CompileEnv, @core.Diagnostic] {
  let env = @core.CompileEnv::empty()
  for directive in leading_use_directives(current.doc) {
    if !has_suffix(directive.target, ".sia") {
      return Err(
        diagnostic(
          directive.span,
          Binding,
          "(use ...) can only import .sia files",
          hint="target was: " + directive.target,
        ),
      )
    }
    let target_path = resolve_relative(current.file.path, directive.target)
    match find_parsed_source(parsed, target_path) {
      Some(library) =>
        match library.kind {
          Sia => {
            let module_name = library.module_name.unwrap_or("")
            match
              collect_prefixed_library_env(
                module_name,
                library.doc,
                builtin_env,
              ) {
              Ok(library_env) => env.append(library_env)
              Err(error) => return Err(error)
            }
          }
          Alt =>
            return Err(
              diagnostic(
                directive.span,
                Binding,
                "(use ...) cannot import .alt files",
                hint="target was: " + directive.target,
              ),
            )
        }
      None =>
        return Err(
          diagnostic(
            directive.span,
            Binding,
            "missing .sia library: " + directive.target,
            hint="resolved path: " + target_path,
          ),
        )
    }
  }
  Ok(env)
}

///|
fn build_unresolved_sections(
  parsed : Array[ParsedSource],
  builtin_env : @core.CompileEnv,
) -> Result[Array[UnresolvedSection], @core.Diagnostic] {
  let sections : Array[UnresolvedSection] = []
  for item in parsed {
    match item.kind {
      Alt => {
        let imported = match build_import_env(item, parsed, builtin_env) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let env = builtin_env.copy()
        env.append(imported)
        let id = section_id_from_path(item.file.path)
        let doc = strip_leading_use_directives(item.doc)
        let metadata = metadata_from_doc(id, item.file.path, doc)
        let section_id = metadata.section_id
        if find_section_index(sections, section_id) != None {
          return Err(
            source_diagnostic(
              item.file.path,
              Binding,
              "duplicate section id: " + section_id,
            ),
          )
        }
        sections.push({
          id: section_id,
          path: item.file.path,
          doc,
          env,
          metadata,
        })
      }
      Sia => ()
    }
  }
  Ok(sections)
}

///|
pub fn Project::new(root : String, sources : Array[SourceFile]) -> Project {
  { root, sources }
}

///|
pub fn compile_project(
  project : Project,
  builtin_env? : @core.CompileEnv,
) -> Result[CompiledProject, @core.Diagnostic] {
  let base_env = builtin_env.unwrap_or(@core.CompileEnv::empty())
  let parsed = match parse_project_sources(project.sources) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let unresolved = match build_unresolved_sections(parsed, base_env) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let state = CompileState::new(project.root, unresolved)
  state.compile_all()
}
