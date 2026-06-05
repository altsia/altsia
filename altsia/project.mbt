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
priv struct TreeExtraction {
  visible_nodes : Array[@core.Node]
  trees : Array[UnresolvedTree]
  next_anonymous_index : Int
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
fn build_unresolved_trees(
  parsed : ParsedProject,
  builtin_env : @core.CompileEnv,
) -> Result[Array[UnresolvedTree], @core.Diagnostic] {
  let trees : Array[UnresolvedTree] = []
  let tree_sources_by_slug : Map[String, String] = Map([])
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
        let default_slug = tree_slug_from_path(item.file.path)
        let source_doc = strip_leading_use_directives(item.doc)
        let metadata_env = match collect_document_env(source_doc, env) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let root_metadata = match
          metadata_from_doc(
            default_slug,
            item.file.path,
            source_doc,
            metadata_env,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let top_level_slug = root_metadata.slug
        let extraction = match
          extract_tree_nodes(
            source_doc.nodes,
            top_level_slug,
            item.file.path,
            env,
            dependencies,
            next_anonymous_index=0,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let root_doc : @core.Document = {
          source: source_doc.source,
          nodes: extraction.visible_nodes,
        }
        let root_content = match compile_graph_content(root_doc, env~) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let root_tree = {
          slug: top_level_slug,
          path: item.file.path,
          content: root_content,
          env,
          metadata: root_metadata,
          dependencies,
        }
        match add_unresolved_tree(trees, tree_sources_by_slug, root_tree) {
          Some(error) => return Err(error)
          None => ()
        }
        for tree in extraction.trees {
          match add_unresolved_tree(trees, tree_sources_by_slug, tree) {
            Some(error) => return Err(error)
            None => ()
          }
        }
      }
      Sia => ()
    }
  }
  Ok(trees)
}

///|
fn collect_document_env(
  doc : @core.Document,
  base_env : @core.CompileEnv,
) -> Result[@core.CompileEnv, @core.Diagnostic] {
  let options : @core.BindingCollectOptions = {
    include_meta: false,
    include_let: true,
    include_def: true,
  }
  @core.collect_bindings(doc, base=base_env, options~)
}

///|
fn add_unresolved_tree(
  trees : Array[UnresolvedTree],
  tree_sources_by_slug : Map[String, String],
  tree : UnresolvedTree,
) -> @core.Diagnostic? {
  let key = tree.slug.canonical()
  match tree_sources_by_slug.get(key) {
    Some(existing_path) =>
      Some(
        source_diagnostic(
          tree.path,
          Binding,
          "duplicate tree slug: " + key,
          hint="previous tree source: " + existing_path,
        ),
      )
    None => {
      tree_sources_by_slug[key] = tree.path
      trees.push(tree)
      None
    }
  }
}

///|
fn extract_tree_nodes(
  nodes : Array[@core.Node],
  top_level_slug : TreeSlug,
  source_path : String,
  env : @core.CompileEnv,
  dependencies : Array[SourceDependency],
  next_anonymous_index~ : Int,
) -> Result[TreeExtraction, @core.Diagnostic] {
  let visible_nodes : Array[@core.Node] = []
  let trees : Array[UnresolvedTree] = []
  let mut next_index = next_anonymous_index
  for node in nodes {
    match node {
      Element("tree", attrs, children, span) =>
        match tree_slug_attr(attrs) {
          Some(local_slug) => {
            let slug = child_tree_slug(top_level_slug, local_slug)
            let child = match
              extract_tree_nodes(
                children,
                top_level_slug,
                source_path,
                env,
                dependencies,
                next_anonymous_index=next_index,
              ) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            next_index = child.next_anonymous_index
            let doc : @core.Document = {
              source: {
                id: Some(source_path),
                line_offset: 0,
                column_offset: 0,
              },
              nodes: child.visible_nodes,
            }
            let metadata_env = match collect_document_env(doc, env) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            let content = match compile_graph_content(doc, env~) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            trees.push({
              slug,
              path: source_path,
              content,
              env,
              metadata: match
                metadata_from_tree(slug, source_path, attrs, doc, metadata_env) {
                Ok(value) => value
                Err(error) => return Err(error)
              },
              dependencies,
            })
            trees.append(child.trees)
            visible_nodes.push(tree_embed_node(slug, attrs, span))
          }
          None => {
            next_index += 1
            let anchor = anonymous_tree_anchor(top_level_slug, next_index)
            let child = match
              extract_tree_nodes(
                children,
                top_level_slug,
                source_path,
                env,
                dependencies,
                next_anonymous_index=next_index,
              ) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            next_index = child.next_anonymous_index
            trees.append(child.trees)
            visible_nodes.push(
              Element(
                "section",
                [html_attr("id", anchor, span)],
                child.visible_nodes,
                span,
              ),
            )
          }
        }
      Element(tag, attrs, children, span) => {
        let child = match
          extract_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            dependencies,
            next_anonymous_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_anonymous_index
        trees.append(child.trees)
        visible_nodes.push(Element(tag, attrs, child.visible_nodes, span))
      }
      When(name, children, span) => {
        let child = match
          extract_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            dependencies,
            next_anonymous_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_anonymous_index
        trees.append(child.trees)
        visible_nodes.push(When(name, child.visible_nodes, span))
      }
      Unless(name, children, span) => {
        let child = match
          extract_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            dependencies,
            next_anonymous_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_anonymous_index
        trees.append(child.trees)
        visible_nodes.push(Unless(name, child.visible_nodes, span))
      }
      _ => visible_nodes.push(node)
    }
  }
  Ok({ visible_nodes, trees, next_anonymous_index: next_index })
}

///|
fn tree_slug_attr(attrs : Array[@core.Attr]) -> String? {
  for attr in attrs {
    if attr.name == "slug" {
      match attr_scalar(attr) {
        Some(value) => return Some(value)
        None => ()
      }
    }
  }
  None
}

///|
fn html_attr(
  name : String,
  value : String,
  span : @core.SourceSpan,
) -> @core.Attr {
  { name, value: Some(Scalar(value, span)), span }
}

///|
fn tree_embed_node(
  slug : TreeSlug,
  attrs : Array[@core.Attr],
  span : @core.SourceSpan,
) -> @core.Node {
  let children : Array[@core.Node] = [Text("/" + slug.canonical(), span)]
  match tree_title_attr(attrs) {
    Some(title) => children.push(Text(title, span))
    None => ()
  }
  Element("embed", [], children, span)
}

///|
fn tree_title_attr(attrs : Array[@core.Attr]) -> String? {
  for attr in attrs {
    if attr.name == "title" {
      match attr_scalar(attr) {
        Some(value) => return Some(value)
        None => ()
      }
    }
  }
  None
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
  let unresolved = match build_unresolved_trees(parsed, base_env) {
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
