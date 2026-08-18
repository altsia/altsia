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
) -> ParsedSource raise @core.Diagnostic {
  guard @model.source_file_kind(file.path) is Some(kind) else {
    raise @model.source_diagnostic(
      file.path,
      Placement,
      "unsupported source file extension: " + file.path,
    )
  }
  let source_info : @core.SourceInfo = {
    id: Some(file.path),
    line_offset: 0,
    column_offset: 0,
  }
  let doc = @core.parse(file.source, source_info~)
  {
    file,
    kind,
    doc,
    module_name: match kind {
      @model.AltLibrary => Some(@model.module_name_from_path(file.path))
      @model.AltDocument => None
    },
  }
}

///|
fn parse_project_sources(
  sources : Array[@model.SourceFile],
) -> ParsedSourceSet raise @core.Diagnostic {
  let parsed : Array[ParsedSource] = []
  let sources_by_path : Map[String, ParsedSource] = Map([])
  for source in sources {
    let item = parse_source_file(source)
    parsed.push(item)
    sources_by_path[@vfs.Path::new(item.file.path).normalize().to_string()] = item
  }
  if check_duplicate_modules(parsed) is Some(error) {
    raise error
  } else {
    { sources: parsed, sources_by_path }
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
  parsed.sources_by_path.get(@vfs.Path::new(path).normalize().to_string())
}

///|
fn resolve_use_directives(
  current : ParsedSource,
  parsed : ParsedSourceSet,
  builtin_env : @core.CompileEnv,
) -> (@core.CompileEnv, Array[@model.SourceFileDependency]) raise @core.Diagnostic {
  let env = @core.CompileEnv::empty()
  let source_file_dependencies : Array[@model.SourceFileDependency] = []
  for directive in leading_use_directives(current.doc) {
    if !directive.target.has_suffix(".sia") {
      raise @model.diagnostic(
        directive.span,
        Binding,
        "(use ...) can only import .sia files",
        hint="target was: " + directive.target,
      )
    }
    let target_path = @vfs.Path::new(current.file.path)
      .resolve(directive.target)
      .to_string()
    match find_parsed_source(parsed, target_path) {
      Some(library) =>
        match library.kind {
          @model.AltLibrary => {
            source_file_dependencies.push({
              source: current.file.path,
              target: library.file.path,
              kind: @model.LibraryUse,
            })
            let module_name = library.module_name.unwrap_or("")
            env.append(
              collect_prefixed_library_env(
                module_name,
                library.doc,
                builtin_env,
              ),
            )
          }
          @model.AltDocument =>
            raise @model.diagnostic(
              directive.span,
              Binding,
              "(use ...) cannot import .alt files",
              hint="target was: " + directive.target,
            )
        }
      None =>
        raise @model.diagnostic(
          directive.span,
          Binding,
          "missing .sia library: " + directive.target,
          hint="resolved path: " + target_path,
        )
    }
  }
  (env, source_file_dependencies)
}

///|
fn lower_parsed_sources(
  parsed : ParsedSourceSet,
  builtin_env : @core.CompileEnv,
) -> Array[@model.ParsedTree] raise @core.Diagnostic {
  let trees : Array[@model.ParsedTree] = []
  let tree_sources_by_slug : Map[String, String] = Map([])
  for item in parsed.sources {
    match item.kind {
      @model.AltDocument => {
        let (imported, source_file_dependencies) = resolve_use_directives(
          item, parsed, builtin_env,
        )
        let env = builtin_env.copy()
        env.append(imported)
        let default_slug = @model.TreeSlug::from_file_path(item.file.path)
        let source_doc = strip_leading_use_directives(item.doc)
        let metadata_env = collect_local_bindings(source_doc, env)
        let root_metadata = metadata_from_doc(
          default_slug,
          item.file.path,
          source_doc,
          metadata_env,
        )
        let top_level_slug = root_metadata.slug
        let extraction = lower_tree_nodes(
          source_doc.nodes,
          top_level_slug,
          item.file.path,
          env,
          source_file_dependencies,
          next_section_index=0,
        )
        let root_doc : @core.Document = {
          source: source_doc.source,
          nodes: extraction.inline_nodes,
        }
        let root_content = @content.compile_rich_content(root_doc, env~)
        let root_tree : @model.ParsedTree = {
          slug: top_level_slug,
          path: item.file.path,
          content: root_content,
          metadata: root_metadata,
          source_file_dependencies,
        }
        if add_parsed_tree(trees, tree_sources_by_slug, root_tree)
          is Some(error) {
          raise error
        }
        for tree in extraction.trees {
          if add_parsed_tree(trees, tree_sources_by_slug, tree) is Some(error) {
            raise error
          }
        }
      }
      @model.AltLibrary => ()
    }
  }
  trees
}

///|
fn collect_local_bindings(
  doc : @core.Document,
  base_env : @core.CompileEnv,
) -> @core.CompileEnv {
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
) -> TreeLowering raise @core.Diagnostic {
  let inline_nodes : Array[@core.Node] = []
  let trees : Array[@model.ParsedTree] = []
  let mut next_index = next_section_index
  for node in nodes {
    match node {
      Element("tree", attrs, children, span) => {
        let slug_attr = tree_slug_attr(attrs)
        match slug_attr {
          Some(local_slug) => {
            let slug = top_level_slug.child(local_slug)
            let child = lower_tree_nodes(
              children,
              top_level_slug,
              source_path,
              env,
              source_file_dependencies,
              next_section_index=next_index,
            )
            next_index = child.next_section_index
            let doc : @core.Document = {
              source: {
                id: Some(source_path),
                line_offset: 0,
                column_offset: 0,
              },
              nodes: child.inline_nodes,
            }
            let metadata_env = collect_local_bindings(doc, env)
            let content = @content.compile_rich_content(doc, env~)
            let extracted_tree : @model.ParsedTree = {
              slug,
              path: source_path,
              content,
              metadata: metadata_from_tree(
                slug, source_path, attrs, doc, metadata_env,
              ),
              source_file_dependencies,
            }
            trees.push(extracted_tree)
            trees.append(child.trees)
            let reference = embedded_tree_reference_node(slug, attrs, span)
            inline_nodes.push(reference)
          }
          None => {
            next_index += 1
            let anchor = top_level_slug.anonymous_anchor(next_index)
            let child = lower_tree_nodes(
              children,
              top_level_slug,
              source_path,
              env,
              source_file_dependencies,
              next_section_index=next_index,
            )
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
      }
      Element(tag, attrs, children, span) => {
        let child = lower_tree_nodes(
          children,
          top_level_slug,
          source_path,
          env,
          source_file_dependencies,
          next_section_index=next_index,
        )
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(Element(tag, attrs, child.inline_nodes, span))
      }
      When(name, children, span) => {
        let child = lower_tree_nodes(
          children,
          top_level_slug,
          source_path,
          env,
          source_file_dependencies,
          next_section_index=next_index,
        )
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(When(name, child.inline_nodes, span))
      }
      Unless(name, children, span) => {
        let child = lower_tree_nodes(
          children,
          top_level_slug,
          source_path,
          env,
          source_file_dependencies,
          next_section_index=next_index,
        )
        next_index = child.next_section_index
        trees.append(child.trees)
        inline_nodes.push(Unless(name, child.inline_nodes, span))
      }
      _ => inline_nodes.push(node)
    }
  }
  { inline_nodes, trees, next_section_index: next_index }
}

///|
fn tree_slug_attr(attrs : Array[@core.Attr]) -> String? raise @core.Diagnostic {
  for attr in attrs {
    if attr.name == "slug" {
      return optional_literal_attr_scalar(
        attr, "tree slug requires a literal scalar",
      )
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
  { name, value: Some(Scalar(Text(value), span)), span }
}

///|
fn embedded_tree_reference_node(
  slug : @model.TreeSlug,
  attrs : Array[@core.Attr],
  span : @core.SourceSpan,
) -> @core.Node raise @core.Diagnostic {
  let children : Array[@core.Node] = [Text("/" + slug.canonical(), span)]
  let title = tree_title_attr(attrs)
  if title is Some(title) {
    children.push(Text(title, span))
  }
  Element("embed", [], children, span)
}

///|
fn tree_title_attr(attrs : Array[@core.Attr]) -> String? raise @core.Diagnostic {
  for attr in attrs {
    if attr.name == "title" {
      return optional_literal_attr_scalar(
        attr, "tree title requires a literal scalar",
      )
    }
  }
  None
}

///|
fn optional_literal_attr_scalar(
  attr : @core.Attr,
  message : String,
) -> String? raise @core.Diagnostic {
  match attr.value {
    Some(value) => Some(value.to_literal_scalar(attr.span, message))
    None => None
  }
}

///|
pub fn parse_project_trees(
  project : @model.Project,
  builtin_env? : @core.CompileEnv,
) -> Array[@model.ParsedTree] raise @core.Diagnostic {
  let base_env = builtin_env.unwrap_or(@core.CompileEnv::empty())
  lower_parsed_sources(parse_project_sources(project.sources), base_env)
}
