///|
priv struct CompileState {
  root : String
  unresolved : Array[UnresolvedSection]
  compiled : Array[CompiledSection]
  diagnostics : Array[@core.Diagnostic]
  active_stack : Array[String]
  reference_edges : Array[(String, String)]
  backlink_edges : Array[(String, String)]
}

///|
fn CompileState::new(
  root : String,
  unresolved : Array[UnresolvedSection],
) -> CompileState {
  {
    root,
    unresolved,
    compiled: [],
    diagnostics: [],
    active_stack: [],
    reference_edges: [],
    backlink_edges: [],
  }
}

///|
fn CompileState::compile_all(
  self : CompileState,
) -> Result[CompiledProject, @core.Diagnostic] {
  for section in self.unresolved {
    match self.compile_section(section.id) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  self.apply_edges()
  self.order_compiled_sections()
  Ok({ root: self.root, sections: self.compiled, diagnostics: self.diagnostics })
}

///|
fn CompileState::find_unresolved(
  self : CompileState,
  id : String,
) -> UnresolvedSection? {
  for section in self.unresolved {
    if section.id == id {
      return Some(section)
    }
  }
  None
}

///|
fn CompileState::find_compiled(
  self : CompileState,
  id : String,
) -> CompiledSection? {
  match find_compiled_index(self.compiled, id) {
    Some(index) => Some(self.compiled[index])
    None => None
  }
}

///|
fn CompileState::compile_section(
  self : CompileState,
  id : String,
) -> Result[CompiledSection, @core.Diagnostic] {
  match self.find_compiled(id) {
    Some(section) => return Ok(section)
    None => ()
  }
  for active in self.active_stack {
    if active == id {
      return Err(self.cycle_diagnostic(id))
    }
  }
  let section = match self.find_unresolved(id) {
    Some(value) => value
    None => return Err(source_diagnostic(id, Binding, "missing section: " + id))
  }
  self.active_stack.push(id)
  let html = match self.compile_section_html(section) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let _ = self.active_stack.pop()
  let compiled = {
    id,
    path: section.path,
    html,
    metadata: section.metadata,
    references: [],
    backlinks: [],
    parent: section.metadata.parent,
  }
  self.compiled.push(compiled)
  Ok(compiled)
}

///|
fn CompileState::cycle_diagnostic(
  self : CompileState,
  id : String,
) -> @core.Diagnostic {
  let chain = self.active_stack.join(" -> ") + " -> " + id
  source_diagnostic(id, Binding, "cyclic embed", hint=chain)
}

///|
fn CompileState::compile_section_html(
  self : CompileState,
  section : UnresolvedSection,
) -> Result[String, @core.Diagnostic] {
  let resolver : @html.ElementResolver = (call, _context) => {
    match call.tag {
      "link" => self.resolve_link(call, section.id, section.path)
      "embed" => self.resolve_embed(call, section.id)
      _ => Ok(None)
    }
  }
  let options = @html.CompileOptions::document_body()
  let options = { ..options, extensions: [resolver] }
  match @html.compile_fragment(section.doc, env=section.env, options~) {
    Ok(nodes) => Ok(@sexp.render_html(nodes))
    Err(error) => Err(error)
  }
}

///|
fn CompileState::resolve_link(
  self : CompileState,
  call : @html.ElementCall,
  source_id : String,
  source_path : String,
) -> Result[Array[@sexp.SexpNode]?, @core.Diagnostic] {
  let target = match first_text_child(call.children) {
    Some(value) => value
    None =>
      return Err(diagnostic(call.span, Binding, "(link ...) requires a target"))
  }
  let text = rest_text(call.children, start=1)
  let resolved_id = section_id_from_path(resolve_relative(source_path, target))
  match self.find_unresolved(resolved_id) {
    Some(target_section) => {
      match self.find_unresolved(source_id) {
        Some(source_section) => {
          if target_section.metadata.asref && source_id != resolved_id {
            self.reference_edges.push((source_id, resolved_id))
          }
          if source_section.metadata.asback && source_id != resolved_id {
            self.backlink_edges.push((source_id, resolved_id))
          }
        }
        None => ()
      }
      let title = match text {
        Some(value) => value
        None =>
          match self.compile_section(resolved_id) {
            Ok(section) => section_title(section)
            Err(_) => resolved_id
          }
      }
      Ok(
        Some([
          Element("a", [("href", Some(url_for_section(resolved_id)))], [
            Text(title),
          ]),
        ]),
      )
    }
    None => {
      self.diagnostics.push(
        diagnostic(call.span, Binding, "dangling local link: " + target),
      )
      let label = text.unwrap_or(target)
      Ok(
        Some([
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
fn CompileState::resolve_embed(
  self : CompileState,
  call : @html.ElementCall,
  parent_id : String,
) -> Result[Array[@sexp.SexpNode]?, @core.Diagnostic] {
  let target = match embed_target(call.children) {
    Some(value) => value
    None =>
      return Err(
        diagnostic(call.span, Binding, "(embed ...) requires a target"),
      )
  }
  let source_path = match self.find_unresolved(parent_id) {
    Some(section) => section.path
    None => parent_id
  }
  let resolved_id = section_id_from_path(resolve_relative(source_path, target))
  match self.find_unresolved(resolved_id) {
    Some(_) =>
      match self.compile_section(resolved_id) {
        Ok(section) => {
          self.set_inferred_parent(resolved_id, parent_id)
          Ok(
            Some([
              Element(
                "div",
                [("class", Some("embed")), ("data-section", Some(resolved_id))],
                [RawHtml(section.html)],
              ),
            ]),
          )
        }
        Err(error) => Err(error)
      }
    None =>
      Err(diagnostic(call.span, Binding, "missing embed target: " + target))
  }
}

///|
fn CompileState::set_inferred_parent(
  self : CompileState,
  id : String,
  parent_id : String,
) -> Unit {
  match find_compiled_index(self.compiled, id) {
    Some(index) =>
      if self.compiled[index].metadata.parent == None {
        self.compiled[index] = {
          ..self.compiled[index],
          parent: Some(parent_id),
        }
      }
    None => ()
  }
}

///|
fn CompileState::apply_edges(self : CompileState) -> Unit {
  for i in 0..<self.compiled.length() {
    let section = self.compiled[i]
    let references : Array[String] = []
    let backlinks : Array[String] = []
    for edge in self.reference_edges {
      let (source, target) = edge
      if source == section.id && !contains_string(references, target) {
        references.push(target)
      }
    }
    for edge in self.backlink_edges {
      let (source, target) = edge
      if target == section.id && !contains_string(backlinks, source) {
        backlinks.push(source)
      }
    }
    self.compiled[i] = { ..section, references, backlinks }
  }
}

///|
fn CompileState::order_compiled_sections(self : CompileState) -> Unit {
  let ordered : Array[CompiledSection] = []
  for unresolved in self.unresolved {
    match self.find_compiled(unresolved.id) {
      Some(section) => ordered.push(section)
      None => ()
    }
  }
  self.compiled.clear()
  self.compiled.append(ordered)
}

///|
fn contains_string(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
pub fn compile_content_chunks(
  doc : @core.Document,
  env? : @core.CompileEnv,
) -> Result[CompiledContent, @core.Diagnostic] {
  let chunks : CompiledContent = []
  let pending : Array[@core.Node] = []
  fn flush() -> Result[Unit, @core.Diagnostic] {
    if pending.length() > 0 {
      let fragment_doc : @core.Document = {
        source: doc.source,
        nodes: pending.copy(),
      }
      let compile_env = env.unwrap_or(@core.CompileEnv::empty())
      match @html.compile_fragment(fragment_doc, env=compile_env) {
        Ok(nodes) => chunks.push(HtmlChunk(@sexp.render_html(nodes)))
        Err(error) => return Err(error)
      }
      pending.clear()
    }
    Ok(())
  }
  for node in doc.nodes {
    match node {
      Element("link", _, children, span) => {
        match flush() {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        let target = first_text_child(children).unwrap_or("")
        chunks.push(
          LocalLinkChunk({ target, text: rest_text(children, start=1), span }),
        )
      }
      Element("embed", _, children, span) => {
        match flush() {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        let target = embed_target(children).unwrap_or("")
        chunks.push(
          EmbedChunk({
            target,
            title: rest_text(children, start=1),
            option: SectionOption::default(),
            span,
          }),
        )
      }
      _ => pending.push(node)
    }
  }
  match flush() {
    Err(error) => Err(error)
    Ok(_) => Ok(chunks)
  }
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
      match
        find_compiled_index(compiled.sections, section_id_from_path(entry)) {
        Some(index) => Ok(compiled.sections[index].html)
        None =>
          Err(
            source_diagnostic(entry, Binding, "missing entry section: " + entry),
          )
      }
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
