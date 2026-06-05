///|
priv struct CompileState {
  root : String
  unresolved_order : Array[String]
  unresolved_by_slug : Map[String, UnresolvedTree]
  compiled_by_slug : Map[String, CompiledTree]
  diagnostics : Array[@core.Diagnostic]
  visiting : Set[String]
  active_stack : Array[String]
  references_by_source : Map[String, Array[TreeSlug]]
  reference_edge_keys : Set[String]
  backlinks_by_target : Map[String, Array[TreeSlug]]
  backlink_edge_keys : Set[String]
  dependencies : Array[SourceDependency]
  dependency_keys : Set[String]
  missing_targets : Array[MissingTarget]
  missing_target_keys : Set[String]
}

///|
fn CompileState::new(
  root : String,
  unresolved : Array[UnresolvedTree],
) -> CompileState {
  let unresolved_order : Array[String] = []
  let unresolved_by_slug : Map[String, UnresolvedTree] = Map([])
  for tree in unresolved {
    let key = tree.slug.canonical()
    unresolved_order.push(key)
    unresolved_by_slug[key] = tree
  }
  let dependencies = collect_initial_dependencies(unresolved)
  {
    root,
    unresolved_order,
    unresolved_by_slug,
    compiled_by_slug: Map([]),
    diagnostics: [],
    visiting: Set([]),
    active_stack: [],
    references_by_source: Map([]),
    reference_edge_keys: Set([]),
    backlinks_by_target: Map([]),
    backlink_edge_keys: Set([]),
    dependencies,
    dependency_keys: dependency_key_set(dependencies),
    missing_targets: [],
    missing_target_keys: Set([]),
  }
}

///|
fn CompileState::compile_all(
  self : CompileState,
) -> Result[CompiledProject, @core.Diagnostic] {
  for slug in self.unresolved_order {
    match self.compile_tree(slug) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  self.apply_edges()
  Ok({
    root: self.root,
    trees: self.ordered_compiled_trees(),
    trees_by_slug: self.compiled_by_slug,
    diagnostics: self.diagnostics,
    dependencies: self.dependencies,
    missing_targets: self.missing_targets,
  })
}

///|
fn collect_initial_dependencies(
  unresolved : Array[UnresolvedTree],
) -> Array[SourceDependency] {
  let dependencies : Array[SourceDependency] = []
  let keys : Set[String] = Set([])
  for tree in unresolved {
    for dependency in tree.dependencies {
      let key = dependency_key(
        dependency.source,
        dependency.target,
        dependency.kind,
      )
      if !keys.contains(key) {
        keys.add(key)
        dependencies.push(dependency)
      }
    }
  }
  dependencies
}

///|
fn dependency_key_set(dependencies : Array[SourceDependency]) -> Set[String] {
  let keys : Set[String] = Set([])
  for dependency in dependencies {
    keys.add(
      dependency_key(dependency.source, dependency.target, dependency.kind),
    )
  }
  keys
}

///|
fn CompileState::find_unresolved(
  self : CompileState,
  slug : String,
) -> UnresolvedTree? {
  self.unresolved_by_slug.get(slug)
}

///|
fn CompileState::find_compiled(
  self : CompileState,
  slug : String,
) -> CompiledTree? {
  self.compiled_by_slug.get(slug)
}

///|
fn CompileState::compile_tree(
  self : CompileState,
  slug : String,
) -> Result[CompiledTree, @core.Diagnostic] {
  match self.find_compiled(slug) {
    Some(tree) => return Ok(tree)
    None => ()
  }
  if self.visiting.contains(slug) {
    return Err(self.cycle_diagnostic(slug))
  }
  let tree = match self.find_unresolved(slug) {
    Some(value) => value
    None =>
      return Err(source_diagnostic(slug, Binding, "missing tree: " + slug))
  }
  self.visiting.add(slug)
  self.active_stack.push(slug)
  let result = self.render_tree_content(tree)
  let _ = self.active_stack.pop()
  self.visiting.remove(slug)
  let html = match result {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let compiled = {
    slug: tree.slug,
    path: tree.path,
    html,
    metadata: tree.metadata,
    references: [],
    backlinks: [],
    parent: tree.metadata.parent,
  }
  self.compiled_by_slug[slug] = compiled
  Ok(compiled)
}

///|
fn CompileState::cycle_diagnostic(
  self : CompileState,
  slug : String,
) -> @core.Diagnostic {
  let chain = self.active_stack.join(" -> ") + " -> " + slug
  source_diagnostic(slug, Binding, "cyclic embed", hint=chain)
}

///|
fn CompileState::render_tree_content(
  self : CompileState,
  tree : UnresolvedTree,
) -> Result[String, @core.Diagnostic] {
  self.render_graph_content(tree.content, tree.slug.canonical(), tree.path)
}

///|
fn CompileState::render_graph_content(
  self : CompileState,
  content : GraphContent,
  source_slug : String,
  source_path : String,
) -> Result[String, @core.Diagnostic] {
  let chunks : Array[String] = []
  for chunk in content {
    match chunk {
      HtmlContent(html) => chunks.push(html)
      CallbackContent(callback) =>
        match self.resolve_graph_callback(callback, source_slug, source_path) {
          Ok(html) => chunks.push(html)
          Err(error) => return Err(error)
        }
    }
  }
  Ok(chunks.join(""))
}

///|
fn CompileState::resolve_graph_callback(
  self : CompileState,
  callback : GraphCallback,
  source_slug : String,
  source_path : String,
) -> Result[String, @core.Diagnostic] {
  match callback {
    LinkCallback(link) =>
      self.resolve_link_content(link, source_slug, source_path)
    EmbedCallback(embed) =>
      self.resolve_embed_content(embed, source_slug, source_path)
  }
}

///|
fn CompileState::resolve_link_content(
  self : CompileState,
  link : LinkContent,
  source_slug : String,
  source_path : String,
) -> Result[String, @core.Diagnostic] {
  let target = link.target
  let resolved_slug = tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_unresolved(resolved_key) {
    Some(target_tree) => {
      self.add_dependency(source_path, target_tree.path, LocalLink)
      match self.find_unresolved(source_slug) {
        Some(source_tree) => {
          if target_tree.metadata.asref && source_slug != resolved_key {
            self.add_reference_edge(source_slug, resolved_slug)
          }
          if source_tree.metadata.asback && source_slug != resolved_key {
            self.add_backlink_edge(resolved_key, source_tree.slug)
          }
        }
        None => ()
      }
      let title = match link.text {
        Some(value) => @sexp.render_html([Text(value)])
        None =>
          match self.compile_tree(resolved_key) {
            Ok(tree) => self.render_link_fallback_title(tree, resolved_key)
            Err(_) => @sexp.render_html([Text(resolved_key)])
          }
      }
      Ok(
        @sexp.render_html([
          Element("a", [("href", Some(url_for_tree(resolved_slug)))], [
            RawHtml(title),
          ]),
        ]),
      )
    }
    None => {
      self.add_missing_target(source_path, target, LocalLink)
      self.diagnostics.push(
        diagnostic(link.span, Binding, "dangling local link: " + target),
      )
      let label = link.text.unwrap_or(target)
      Ok(
        @sexp.render_html([
          Element(
            "a",
            [("href", Some("#")), ("data-missing-target", Some(target))],
            [Text(label)],
          ),
        ]),
      )
    }
  }
}

///|
fn CompileState::render_link_fallback_title(
  self : CompileState,
  tree : CompiledTree,
  fallback : String,
) -> String {
  match tree.metadata.title {
    Some((content, _)) =>
      match
        self.render_graph_content(
          content,
          tree.slug.canonical(),
          tree.path,
        ) {
        Ok(html) => html
        Err(_) => @sexp.render_html([Text(tree_title(tree))])
      }
    None =>
      @sexp.render_html([Text(tree.metadata.page_title.unwrap_or(fallback))])
  }
}

///|
fn CompileState::resolve_embed_content(
  self : CompileState,
  embed : EmbedContent,
  parent_slug : String,
  source_path : String,
) -> Result[String, @core.Diagnostic] {
  let target = embed.target
  let resolved_slug = tree_slug_from_target(source_path, target)
  let resolved_key = resolved_slug.canonical()
  match self.find_unresolved(resolved_key) {
    Some(target_tree) => {
      match self.find_unresolved(parent_slug) {
        Some(source_tree) =>
          self.add_dependency(source_tree.path, target_tree.path, Embed)
        None => ()
      }
      match self.compile_tree(resolved_key) {
        Ok(tree) => {
          self.set_inferred_parent(resolved_key, parent_slug)
          Ok(
            @sexp.render_html([
              Element(
                "div",
                [("class", Some("embed")), ("data-tree", Some(resolved_key))],
                [RawHtml(tree.html)],
              ),
            ]),
          )
        }
        Err(error) => Err(error)
      }
    }
    None =>
      Err(diagnostic(embed.span, Binding, "missing embed target: " + target))
  }
}

///|
fn CompileState::add_dependency(
  self : CompileState,
  source : String,
  target : String,
  kind : DependencyKind,
) -> Unit {
  let key = dependency_key(source, target, kind)
  if !self.dependency_keys.contains(key) {
    self.dependency_keys.add(key)
    self.dependencies.push({ source, target, kind })
  }
}

///|
fn CompileState::add_missing_target(
  self : CompileState,
  source : String,
  target : String,
  kind : DependencyKind,
) -> Unit {
  let key = dependency_key(source, target, kind)
  if !self.missing_target_keys.contains(key) {
    self.missing_target_keys.add(key)
    self.missing_targets.push({ source, target, kind })
  }
}

///|
fn CompileState::add_reference_edge(
  self : CompileState,
  source : String,
  target : TreeSlug,
) -> Unit {
  let key = edge_key(source, target.canonical())
  if !self.reference_edge_keys.contains(key) {
    self.reference_edge_keys.add(key)
    push_map_array(self.references_by_source, source, target)
  }
}

///|
fn CompileState::add_backlink_edge(
  self : CompileState,
  target : String,
  source : TreeSlug,
) -> Unit {
  let key = edge_key(target, source.canonical())
  if !self.backlink_edge_keys.contains(key) {
    self.backlink_edge_keys.add(key)
    push_map_array(self.backlinks_by_target, target, source)
  }
}

///|
fn CompileState::set_inferred_parent(
  self : CompileState,
  slug : String,
  parent_slug : String,
) -> Unit {
  match self.compiled_by_slug.get(slug) {
    Some(tree) =>
      if tree.metadata.parent == None {
        self.compiled_by_slug[slug] = {
          ..tree,
          parent: Some(TreeSlug::parse(parent_slug)),
        }
      }
    None => ()
  }
}

///|
fn CompileState::apply_edges(self : CompileState) -> Unit {
  for slug in self.unresolved_order {
    let tree = match self.compiled_by_slug.get(slug) {
      Some(tree) => tree
      None => continue
    }
    let references : Array[TreeSlug] = []
    let backlinks : Array[TreeSlug] = []
    match self.references_by_source.get(slug) {
      Some(values) => references.append(values)
      None => ()
    }
    match self.backlinks_by_target.get(slug) {
      Some(values) => backlinks.append(values)
      None => ()
    }
    self.compiled_by_slug[slug] = { ..tree, references, backlinks }
  }
}

///|
fn CompileState::ordered_compiled_trees(
  self : CompileState,
) -> Array[CompiledTree] {
  let ordered : Array[CompiledTree] = []
  for slug in self.unresolved_order {
    match self.compiled_by_slug.get(slug) {
      Some(tree) => ordered.push(tree)
      None => ()
    }
  }
  ordered
}

///|
fn push_map_array(
  table : Map[String, Array[TreeSlug]],
  key : String,
  value : TreeSlug,
) -> Unit {
  match table.get(key) {
    Some(values) => {
      values.push(value)
      table[key] = values
    }
    None => table[key] = [value]
  }
}

///|
fn dependency_key(
  source : String,
  target : String,
  kind : DependencyKind,
) -> String {
  source + "\u{1f}" + target + "\u{1f}" + dependency_kind_key(kind)
}

///|
fn edge_key(source : String, target : String) -> String {
  source + "\u{1f}" + target
}

///|
fn dependency_kind_key(kind : DependencyKind) -> String {
  match kind {
    UseLibrary => "use"
    LocalLink => "link"
    Embed => "embed"
  }
}

///|
pub fn compile_graph_content(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[GraphContent, @core.Diagnostic] {
  match env {
    Some(env) => compile_graph_content_with_wrap(doc, env, wrap_paragraphs=true)
    None =>
      compile_graph_content_with_wrap(
        doc,
        @core.CompileEnv::empty(),
        wrap_paragraphs=true,
      )
  }
}

///|
fn compile_inline_graph_content(
  doc : @core.Document,
  env : @core.CompileEnv,
) -> Result[GraphContent, @core.Diagnostic] {
  compile_graph_content_with_wrap(doc, env, wrap_paragraphs=false)
}

///|
fn compile_graph_content_with_wrap(
  doc : @core.Document,
  compile_env : @core.CompileEnv,
  wrap_paragraphs~ : Bool,
) -> Result[GraphContent, @core.Diagnostic] {
  let captured : Array[GraphCallback] = []
  let resolver : @html.ElementResolver = (call, _context) => {
    match call.tag {
      "link" => {
        let target = match first_text_child(call.children) {
          Some(value) => value
          None =>
            return Err(
              diagnostic(call.span, Binding, "(link ...) requires a target"),
            )
        }
        let index = captured.length()
        captured.push(
          LinkCallback({
            target,
            text: rest_text(call.children, start=1),
            span: call.span,
          }),
        )
        Ok(Some([Text(chunk_marker(index))]))
      }
      "embed" => {
        let target = match embed_target(call.children) {
          Some(value) => value
          None =>
            return Err(
              diagnostic(call.span, Binding, "(embed ...) requires a target"),
            )
        }
        let index = captured.length()
        captured.push(
          EmbedCallback({
            target,
            title: rest_text(call.children, start=1),
            option: EmbedOption::default(),
            span: call.span,
          }),
        )
        Ok(Some([RawHtml(chunk_marker(index))]))
      }
      _ => Ok(None)
    }
  }
  let options = @html.CompileOptions::fragment()
  let options = { ..options, wrap_paragraphs, extensions: [resolver] }
  match @html.compile_fragment(doc, env=compile_env, options~) {
    Ok(nodes) =>
      Ok(graph_content_from_marked_html(@sexp.render_html(nodes), captured))
    Err(error) => Err(error)
  }
}

///|
pub fn compile_content_chunks(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[GraphContent, @core.Diagnostic] {
  match env {
    Some(env) => compile_graph_content(doc, env~)
    None => compile_graph_content(doc)
  }
}

///|
fn chunk_marker(index : Int) -> String {
  "\u{1f}altsia:" + index.to_string() + "\u{1f}"
}

///|
fn graph_content_from_marked_html(
  html : String,
  captured : Array[GraphCallback],
) -> GraphContent {
  let result : GraphContent = []
  let mut remainder = html
  for i in 0..<captured.length() {
    let marker = chunk_marker(i)
    let parts = remainder.split(marker).to_array()
    if parts.length() > 1 {
      let before = parts[0].to_owned()
      if before != "" {
        result.push(HtmlContent(before))
      }
      result.push(CallbackContent(captured[i]))
      let rest : Array[String] = []
      for j in 1..<parts.length() {
        rest.push(parts[j].to_owned())
      }
      remainder = rest.join(marker)
    }
  }
  if remainder != "" {
    result.push(HtmlContent(remainder))
  }
  result
}

///|
fn first_text_child(children : Array[@core.Node]) -> String? {
  if children.length() == 0 {
    None
  } else {
    text_from_node(children[0])
  }
}

///|
fn rest_text(children : Array[@core.Node], start~ : Int) -> String? {
  let parts : Array[String] = []
  for i in start..<children.length() {
    match text_from_node(children[i]) {
      Some(text) => parts.push(text)
      None => ()
    }
  }
  if parts.length() == 0 {
    None
  } else {
    Some(parts.join(" ").trim().to_owned())
  }
}

///|
fn embed_target(children : Array[@core.Node]) -> String? {
  if children.length() == 0 {
    None
  } else {
    match children[0] {
      Element(_, _, _, _) =>
        if children.length() > 1 {
          text_from_node(children[1])
        } else {
          None
        }
      _ => text_from_node(children[0])
    }
  }
}

///|
pub fn compile_alt_fragment(
  sources : Array[SourceFile],
  entry : String,
) -> Result[String, @core.Diagnostic] {
  let project = Project::new("", sources)
  match compile_project(project) {
    Err(error) => Err(error)
    Ok(compiled) =>
      match compiled.trees_by_slug.get(tree_slug_from_path(entry).canonical()) {
        Some(tree) => Ok(tree.html)
        None =>
          Err(source_diagnostic(entry, Binding, "missing entry tree: " + entry))
      }
  }
}

///|
pub fn preview_snapshot(
  snapshot : ProjectSnapshot,
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[PreviewResult, @core.Diagnostic] {
  match options {
    Some(options) =>
      preview_project(
        Project::new(snapshot.root, snapshot.sources),
        entry,
        options~,
      )
    None =>
      preview_project(Project::new(snapshot.root, snapshot.sources), entry)
  }
}

///|
pub fn preview_project(
  project : Project,
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[PreviewResult, @core.Diagnostic] {
  match compile_project(project) {
    Err(error) => Err(error)
    Ok(compiled) => {
      let entry_tree_slug = tree_slug_from_path(entry)
      match compiled.trees_by_slug.get(entry_tree_slug.canonical()) {
        Some(tree) => {
          let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
          let html = @sexp.render_html_document(
            [],
            opts.extra_head,
            [RawHtml(tree.html)],
            opts.doctype,
          )
          Ok({
            html,
            diagnostics: compiled.diagnostics,
            dependencies: dependencies_for_entry(
              compiled.dependencies,
              tree.path,
            ),
            missing_targets: missing_targets_for_entry(
              compiled.missing_targets,
              compiled.dependencies,
              tree.path,
            ),
            entry_tree_slug,
            title: tree_page_title(tree),
          })
        }
        None =>
          Err(source_diagnostic(entry, Binding, "missing entry tree: " + entry))
      }
    }
  }
}

///|
pub fn check_project(
  project : Project,
) -> Result[CompiledProject, @core.Diagnostic] {
  compile_project_strict(project)
}

///|
pub fn check_snapshot(
  snapshot : ProjectSnapshot,
) -> Result[CompiledProject, @core.Diagnostic] {
  compile_project_strict(Project::new(snapshot.root, snapshot.sources))
}

///|
fn dependencies_for_entry(
  dependencies : Array[SourceDependency],
  entry_path : String,
) -> Array[SourceDependency] {
  let by_source : Map[String, Array[SourceDependency]] = Map([])
  for dependency in dependencies {
    push_dependency_map_array(by_source, dependency.source, dependency)
  }
  let result : Array[SourceDependency] = []
  let emitted : Set[String] = Set([])
  let visited : Set[String] = Set([])
  let queue : Array[String] = [entry_path]
  let mut cursor = 0
  visited.add(entry_path)
  while cursor < queue.length() {
    let source = queue[cursor]
    cursor += 1
    match by_source.get(source) {
      Some(edges) =>
        for dependency in edges {
          let key = dependency_key(
            dependency.source,
            dependency.target,
            dependency.kind,
          )
          if !emitted.contains(key) {
            emitted.add(key)
            result.push(dependency)
          }
          if !visited.contains(dependency.target) {
            visited.add(dependency.target)
            queue.push(dependency.target)
          }
        }
      None => ()
    }
  }
  result
}

///|
fn missing_targets_for_entry(
  missing_targets : Array[MissingTarget],
  dependencies : Array[SourceDependency],
  entry_path : String,
) -> Array[MissingTarget] {
  let result : Array[MissingTarget] = []
  let reachable : Set[String] = Set([entry_path])
  let deps = dependencies_for_entry(dependencies, entry_path)
  for dep in deps {
    reachable.add(dep.source)
    reachable.add(dep.target)
  }
  for missing in missing_targets {
    if reachable.contains(missing.source) {
      result.push(missing)
    }
  }
  result
}

///|
fn push_dependency_map_array(
  table : Map[String, Array[SourceDependency]],
  key : String,
  value : SourceDependency,
) -> Unit {
  match table.get(key) {
    Some(values) => {
      values.push(value)
      table[key] = values
    }
    None => table[key] = [value]
  }
}

///|
pub fn compile_alt_document(
  sources : Array[SourceFile],
  entry : String,
  options? : @html.HtmlDocumentOptions,
) -> Result[String, @core.Diagnostic] {
  match compile_alt_fragment(sources, entry) {
    Err(error) => Err(error)
    Ok(body) => {
      let opts = options.unwrap_or(@html.HtmlDocumentOptions::default())
      Ok(
        @sexp.render_html_document(
          [],
          opts.extra_head,
          [RawHtml(body)],
          opts.doctype,
        ),
      )
    }
  }
}
