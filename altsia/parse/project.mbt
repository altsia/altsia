///|
priv struct ParsedSource {
  file : @model.SourceFile
  kind : @model.SourceFileKind
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
  trees : Array[@model.ParsedTree]
  next_section_index : Int
}

///|
fn parse_source_file(
  file : @model.SourceFile,
) -> Result[ParsedSource, @core.Diagnostic] {
  guard @model.source_file_kind(file.path) is Some(kind) else {
    return Err(
      @model.source_diagnostic(
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
  @core.parse(file.source, source_info~).map(doc => {
    file,
    kind,
    doc,
    module_name: match kind {
      @model.Sia => Some(@model.module_name_from_path(file.path))
      @model.Alt => None
    },
  })
}

///|
fn parse_project_sources(
  sources : Array[@model.SourceFile],
) -> Result[ParsedSourceSet, @core.Diagnostic] {
  let parsed : Array[ParsedSource] = []
  let sources_by_path : Map[String, ParsedSource] = Map([])
  for source in sources {
    match parse_source_file(source) {
      Ok(item) => {
        parsed.push(item)
        sources_by_path[@model.normalize_path(item.file.path)] = item
      }
      Err(error) => return Err(error)
    }
  }
  if check_duplicate_modules(parsed) is Some(error) {
    Err(error)
  } else {
    Ok({ sources: parsed, sources_by_path })
  }
}

///|
fn check_duplicate_modules(parsed : Array[ParsedSource]) -> @core.Diagnostic? {
  let names : Map[String, String] = Map([])
  for item in parsed {
    if item.module_name is Some(name) {
      if names.get(name) is Some(existing_path) {
        return Some(
          @model.source_diagnostic(
            item.file.path,
            Binding,
            "duplicate .sia module name: " + name,
            hint="previous .sia source: " + existing_path,
          ),
        )
      }
      names[name] = item.file.path
    }
  }
  None
}

///|
fn find_parsed_source(parsed : ParsedSourceSet, path : String) -> ParsedSource? {
  parsed.sources_by_path.get(@model.normalize_path(path))
}

///|
fn resolve_use_directives(
  current : ParsedSource,
  parsed : ParsedSourceSet,
  builtin_env : @core.CompileEnv,
) -> Result[
  (@core.CompileEnv, Array[@model.SourceFileDependency]),
  @core.Diagnostic,
] {
  let env = @core.CompileEnv::empty()
  let source_file_dependencies : Array[@model.SourceFileDependency] = []
  for directive in leading_use_directives(current.doc) {
    if !@model.has_suffix(directive.target, ".sia") {
      return Err(
        @model.diagnostic(
          directive.span,
          Binding,
          "(use ...) can only import .sia files",
          hint="target was: " + directive.target,
        ),
      )
    }
    let target_path = @model.resolve_relative(
      current.file.path,
      directive.target,
    )
    match find_parsed_source(parsed, target_path) {
      Some(library) =>
        match library.kind {
          @model.Sia => {
            source_file_dependencies.push({
              source: current.file.path,
              target: library.file.path,
              kind: @model.LibraryUse,
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
          @model.Alt =>
            return Err(
              @model.diagnostic(
                directive.span,
                Binding,
                "(use ...) cannot import .alt files",
                hint="target was: " + directive.target,
              ),
            )
        }
      None =>
        return Err(
          @model.diagnostic(
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
) -> Result[Array[@model.ParsedTree], @core.Diagnostic] {
  let trees : Array[@model.ParsedTree] = []
  let tree_sources_by_slug : Map[String, String] = Map([])
  for item in parsed.sources {
    match item.kind {
      @model.Alt => {
        let import_result = match
          resolve_use_directives(item, parsed, builtin_env) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let (imported, source_file_dependencies) = import_result
        let env = builtin_env.copy()
        env.append(imported)
        let default_slug = @model.tree_slug_from_path(item.file.path)
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
        let root_content = match @content.compile_rich_content(root_doc, env~) {
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
        if add_parsed_tree(trees, tree_sources_by_slug, root_tree)
          is Some(error) {
          return Err(error)
        }
        for tree in extraction.trees {
          if add_parsed_tree(trees, tree_sources_by_slug, tree) is Some(error) {
            return Err(error)
          }
        }
      }
      @model.Sia => ()
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
    include_doc: false,
    include_let: true,
    include_def: true,
  }
  @core.collect_bindings(doc, base=base_env, options~)
}

///|
fn add_parsed_tree(
  trees : Array[@model.ParsedTree],
  tree_sources_by_slug : Map[String, String],
  tree : @model.ParsedTree,
) -> @core.Diagnostic? {
  let key = tree.slug.canonical()
  match tree_sources_by_slug.get(key) {
    Some(existing_path) =>
      Some(
        @model.source_diagnostic(
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
  top_level_slug : @model.TreeSlug,
  source_path : String,
  env : @core.CompileEnv,
  source_file_dependencies : Array[@model.SourceFileDependency],
  next_section_index~ : Int,
) -> Result[TreeLowering, @core.Diagnostic] {
  let inline_nodes : Array[@core.Node] = []
  let trees : Array[@model.ParsedTree] = []
  let mut next_index = next_section_index
  for node in nodes {
    match node {
      Element("tree", attrs, children, span) =>
        match tree_slug_attr(attrs) {
          Some(local_slug) => {
            let slug = @model.child_tree_slug(top_level_slug, local_slug)
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
            let content = match @content.compile_rich_content(doc, env~) {
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
            let anchor = @model.anonymous_tree_anchor(
              top_level_slug, next_index,
            )
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
      if attr_scalar(attr) is Some(value) {
        return Some(value)
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
  slug : @model.TreeSlug,
  attrs : Array[@core.Attr],
  span : @core.SourceSpan,
) -> @core.Node {
  let children : Array[@core.Node] = [Text("/" + slug.canonical(), span)]
  if tree_title_attr(attrs) is Some(title) {
    children.push(Text(title, span))
  }
  Element("embed", [], children, span)
}

///|
fn tree_title_attr(attrs : Array[@core.Attr]) -> String? {
  for attr in attrs {
    if attr.name == "title" {
      if attr_scalar(attr) is Some(value) {
        return Some(value)
      }
    }
  }
  None
}

///|
pub fn parse_project_trees(
  project : @model.Project,
  builtin_env? : @core.CompileEnv,
) -> Result[Array[@model.ParsedTree], @core.Diagnostic] {
  let base_env = builtin_env.unwrap_or(@core.CompileEnv::empty())
  parse_project_sources(project.sources).bind(parsed => {
    lower_parsed_sources(parsed, base_env)
  })
}
