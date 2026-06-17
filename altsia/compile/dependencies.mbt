///|
fn source_file_dependency_key(
  source : String,
  target : String,
  kind : @model.SourceFileDependencyKind,
) -> String {
  source + "\u{1f}" + target + "\u{1f}" + source_file_dependency_kind_key(kind)
}

///|
fn source_file_dependency_kind_key(
  kind : @model.SourceFileDependencyKind,
) -> String {
  match kind {
    @model.LibraryUse => "library-use"
    @model.TreeLink => "tree-link"
    @model.TreeEmbed => "tree-embed"
  }
}

///|
pub fn expand_dirty_sources(
  project : @model.CompiledProject,
  dirty_sources : Array[String],
) -> Array[String] {
  let graph = dirty_source_file_graph(project.source_file_dependencies)
  let result : Array[String] = []
  let visited : Set[String] = Set([])
  let queue : Array[String] = []
  for source in dirty_sources {
    let normalized = @model.normalize_path(source)
    if !visited.contains(normalized) {
      visited.add(normalized)
      queue.push(normalized)
      result.push(normalized)
    }
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let source = queue[cursor]
    cursor += 1
    match graph.get(source) {
      Some(next_sources) =>
        for next in next_sources {
          if !visited.contains(next) {
            visited.add(next)
            queue.push(next)
            result.push(next)
          }
        }
      None => ()
    }
  }
  result
}

///|
fn dirty_source_file_graph(
  source_file_dependencies : Array[@model.SourceFileDependency],
) -> Map[String, Array[String]] {
  let graph : Map[String, Array[String]] = Map([])
  for dependency in source_file_dependencies {
    match dependency.kind {
      @model.LibraryUse =>
        push_string_map_array(graph, dependency.target, dependency.source)
      @model.TreeLink => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
      @model.TreeEmbed => {
        push_string_map_array(graph, dependency.source, dependency.target)
        push_string_map_array(graph, dependency.target, dependency.source)
      }
    }
  }
  graph
}

///|
pub fn source_file_dependencies_for_entry(
  source_file_dependencies : Array[@model.SourceFileDependency],
  entry_path : String,
) -> Array[@model.SourceFileDependency] {
  let by_source : Map[String, Array[@model.SourceFileDependency]] = Map([])
  for dependency in source_file_dependencies {
    push_source_file_dependency_map_array(
      by_source,
      dependency.source,
      dependency,
    )
  }
  let result : Array[@model.SourceFileDependency] = []
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
          let key = source_file_dependency_key(
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
pub fn dangling_tree_links_for_entry(
  dangling_tree_links : Array[@model.DanglingTreeLink],
  source_file_dependencies : Array[@model.SourceFileDependency],
  entry_path : String,
) -> Array[@model.DanglingTreeLink] {
  let reachable : Set[String] = Set([entry_path])
  let deps = source_file_dependencies_for_entry(
    source_file_dependencies, entry_path,
  )
  for dep in deps {
    reachable.add(dep.source)
    reachable.add(dep.target)
  }
  dangling_tree_links.filter(link => reachable.contains(link.source))
}

///|
fn push_source_file_dependency_map_array(
  table : Map[String, Array[@model.SourceFileDependency]],
  key : String,
  value : @model.SourceFileDependency,
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
fn push_string_map_array(
  table : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  match table.get(key) {
    Some(values) =>
      if !values.contains(value) {
        values.push(value)
        table[key] = values
      }
    None => table[key] = [value]
  }
}
