///|
priv struct ParsedSource {
  file : SourceFile
  kind : SourceKind
  doc : @core.Document
  module_name : String?
}

///|
priv struct ParsedProject {
  sources : Array[ParsedSource]
  by_path : Map[String, ParsedSource]
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
) -> Result[ParsedProject, @core.Diagnostic] {
  let parsed : Array[ParsedSource] = []
  let by_path : Map[String, ParsedSource] = Map([])
  for source in sources {
    match parse_source_file(source) {
      Ok(item) => {
        parsed.push(item)
        by_path[normalize_path(item.file.path)] = item
      }
      Err(error) => return Err(error)
    }
  }
  match check_duplicate_modules(parsed) {
    Some(error) => Err(error)
    None => Ok({ sources: parsed, by_path })
  }
}

///|
fn check_duplicate_modules(parsed : Array[ParsedSource]) -> @core.Diagnostic? {
  let names : Map[String, String] = Map([])
  for item in parsed {
    match item.module_name {
      Some(name) =>
        match names.get(name) {
          Some(existing_path) =>
            return Some(
              source_diagnostic(
                item.file.path,
                Binding,
                "duplicate .sia module name: " + name,
                hint="previous .sia source: " + existing_path,
              ),
            )
          None => names[name] = item.file.path
        }
      None => ()
    }
  }
  None
}

///|
fn find_parsed_source(parsed : ParsedProject, path : String) -> ParsedSource? {
  parsed.by_path.get(normalize_path(path))
}

///|
fn build_import_env(
  current : ParsedSource,
  parsed : ParsedProject,
  builtin_env : @core.CompileEnv,
) -> Result[(@core.CompileEnv, Array[SourceDependency]), @core.Diagnostic] {
  let env = @core.CompileEnv::empty()
  let dependencies : Array[SourceDependency] = []
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
            dependencies.push({
              source: current.file.path,
              target: library.file.path,
              kind: UseLibrary,
            })
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
  Ok((env, dependencies))
}

///|
fn build_unresolved_sections(
  parsed : ParsedProject,
  builtin_env : @core.CompileEnv,
) -> Result[Array[UnresolvedSection], @core.Diagnostic] {
  let sections : Array[UnresolvedSection] = []
  let section_ids : Set[String] = Set([])
  for item in parsed.sources {
    match item.kind {
      Alt => {
        let import_result = match build_import_env(item, parsed, builtin_env) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let (imported, dependencies) = import_result
        let env = builtin_env.copy()
        env.append(imported)
        let id = section_id_from_path(item.file.path)
        let doc = strip_leading_use_directives(item.doc)
        let metadata = metadata_from_doc(id, item.file.path, doc)
        let section_id = metadata.section_id
        if section_ids.contains(section_id) {
          return Err(
            source_diagnostic(
              item.file.path,
              Binding,
              "duplicate section id: " + section_id,
            ),
          )
        }
        section_ids.add(section_id)
        sections.push({
          id: section_id,
          path: item.file.path,
          doc,
          env,
          metadata,
          dependencies,
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
  match builtin_env {
    Some(env) =>
      compile_project_with_options(project, strict=false, builtin_env=env)
    None => compile_project_with_options(project, strict=false)
  }
}

///|
pub fn compile_project_strict(
  project : Project,
  builtin_env? : @core.CompileEnv,
) -> Result[CompiledProject, @core.Diagnostic] {
  match builtin_env {
    Some(env) =>
      compile_project_with_options(project, strict=true, builtin_env=env)
    None => compile_project_with_options(project, strict=true)
  }
}

///|
fn compile_project_with_options(
  project : Project,
  strict~ : Bool,
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
  match state.compile_all() {
    Err(error) => Err(error)
    Ok(compiled) =>
      if strict && compiled.diagnostics.length() > 0 {
        Err(compiled.diagnostics[0])
      } else {
        Ok(compiled)
      }
  }
}
