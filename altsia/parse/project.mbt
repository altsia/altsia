///|
priv struct ParsedSource {
  file : SourceFile
  kind : SourceFileKind
  doc : @core.Document
  module_name : String?
}

///|
priv struct ParsedSourceSet {
  sources : Array[ParsedSource]
  sources_by_path : Map[String, ParsedSource]
}

///|
priv struct TreeLowering {
  inline_nodes : Array[@core.Node]
  trees : Array[ParsedTree]
  next_section_index : Int
}

///|
fn parse_source_file(
  file : SourceFile,
) -> Result[ParsedSource, @core.Diagnostic] {
  let kind = match source_file_kind(file.path) {
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
) -> Result[ParsedSourceSet, @core.Diagnostic] {
  let parsed : Array[ParsedSource] = []
  let sources_by_path : Map[String, ParsedSource] = Map([])
  for source in sources {
    match parse_source_file(source) {
      Ok(item) => {
        parsed.push(item)
        sources_by_path[normalize_path(item.file.path)] = item
      }
      Err(error) => return Err(error)
    }
  }
  match check_duplicate_modules(parsed) {
    Some(error) => Err(error)
    None => Ok({ sources: parsed, sources_by_path })
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
fn find_parsed_source(parsed : ParsedSourceSet, path : String) -> ParsedSource? {
  parsed.sources_by_path.get(normalize_path(path))
}

///|
fn resolve_use_directives(
  current : ParsedSource,
  parsed : ParsedSourceSet,
  builtin_env : @core.CompileEnv,
) -> Result[(@core.CompileEnv, Array[SourceFileDependency]), @core.Diagnostic] {
  let env = @core.CompileEnv::empty()
  let source_file_dependencies : Array[SourceFileDependency] = []
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
            source_file_dependencies.push({
              source: current.file.path,
              target: library.file.path,
              kind: LibraryUse,
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
  Ok((env, source_file_dependencies))
}

///|
fn lower_parsed_sources(
  parsed : ParsedSourceSet,
  builtin_env : @core.CompileEnv,
) -> Result[Array[ParsedTree], @core.Diagnostic] {
  let trees : Array[ParsedTree] = []
  let tree_sources_by_slug : Map[String, String] = Map([])
  for item in parsed.sources {
    match item.kind {
      Alt => {
        let import_result = match
          resolve_use_directives(item, parsed, builtin_env) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let (imported, source_file_dependencies) = import_result
        let env = builtin_env.copy()
        env.append(imported)
        let default_slug = tree_slug_from_path(item.file.path)
        let source_doc = strip_leading_use_directives(item.doc)
        let metadata_env = match collect_local_bindings(source_doc, env) {
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
          lower_tree_nodes(
            source_doc.nodes,
            top_level_slug,
            item.file.path,
            env,
            source_file_dependencies,
            next_section_index=0,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let root_doc : @core.Document = {
          source: source_doc.source,
          nodes: extraction.inline_nodes,
        }
        let root_content = match compile_rich_content(root_doc, env~) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let root_tree : @model.ParsedTree = {
          slug: top_level_slug,
          path: item.file.path,
          content: root_content,
          metadata: root_metadata,
          source_file_dependencies,
        }
        match add_parsed_tree(trees, tree_sources_by_slug, root_tree) {
          Some(error) => return Err(error)
          None => ()
        }
        for tree in extraction.trees {
          match add_parsed_tree(trees, tree_sources_by_slug, tree) {
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
fn collect_local_bindings(
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
fn add_parsed_tree(
  trees : Array[ParsedTree],
  tree_sources_by_slug : Map[String, String],
  tree : ParsedTree,
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
fn lower_tree_nodes(
  nodes : Array[@core.Node],
  top_level_slug : TreeSlug,
  source_path : String,
  env : @core.CompileEnv,
  source_file_dependencies : Array[SourceFileDependency],
  next_section_index~ : Int,
) -> Result[TreeLowering, @core.Diagnostic] {
  let inline_nodes : Array[@core.Node] = []
  let trees : Array[ParsedTree] = []
  let mut next_index = next_section_index
  for node in nodes {
    match node {
      Element("tree", attrs, children, span) =>
        match tree_slug_attr(attrs) {
          Some(local_slug) => {
            let slug = child_tree_slug(top_level_slug, local_slug)
            let child = match
              lower_tree_nodes(
                children,
                top_level_slug,
                source_path,
                env,
                source_file_dependencies,
                next_section_index=next_index,
              ) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            next_index = child.next_section_index
            let doc : @core.Document = {
              source: {
                id: Some(source_path),
                line_offset: 0,
                column_offset: 0,
              },
              nodes: child.inline_nodes,
            }
            let metadata_env = match collect_local_bindings(doc, env) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            let content = match compile_rich_content(doc, env~) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            let extracted_tree : @model.ParsedTree = {
              slug,
              path: source_path,
              content,
              metadata: match
                metadata_from_tree(slug, source_path, attrs, doc, metadata_env) {
                Ok(value) => value
                Err(error) => return Err(error)
              },
              source_file_dependencies,
            }
            trees.push(extracted_tree)
            trees.append(child.trees)
            inline_nodes.push(embedded_tree_reference_node(slug, attrs, span))
          }
          None => {
            next_index += 1
            let anchor = anonymous_tree_anchor(top_level_slug, next_index)
            let child = match
              lower_tree_nodes(
                children,
                top_level_slug,
                source_path,
                env,
                source_file_dependencies,
                next_section_index=next_index,
              ) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
            next_index = child.next_section_index
            trees.append(child.trees)
            inline_nodes.push(
              Element(
                "section",
                [html_attr("id", anchor, span)],
                child.inline_nodes,
                span,
              ),
            )
          }
        }
      Element(tag, attrs, children, span) => {
        let child = match
          lower_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            source_file_dependencies,
            next_section_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(Element(tag, attrs, child.inline_nodes, span))
      }
      When(name, children, span) => {
        let child = match
          lower_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            source_file_dependencies,
            next_section_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(When(name, child.inline_nodes, span))
      }
      Unless(name, children, span) => {
        let child = match
          lower_tree_nodes(
            children,
            top_level_slug,
            source_path,
            env,
            source_file_dependencies,
            next_section_index=next_index,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(Unless(name, child.inline_nodes, span))
      }
      _ => inline_nodes.push(node)
    }
  }
  Ok({ inline_nodes, trees, next_section_index: next_index })
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
fn embedded_tree_reference_node(
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
pub fn parse_project_trees(
  project : Project,
  builtin_env? : @core.CompileEnv,
) -> Result[Array[ParsedTree], @core.Diagnostic] {
  let base_env = builtin_env.unwrap_or(@core.CompileEnv::empty())
  let parsed = match parse_project_sources(project.sources) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  lower_parsed_sources(parsed, base_env)
}
