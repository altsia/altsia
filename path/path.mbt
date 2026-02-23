///|
enum PathKind {
  Local(Bool, Array[String])
  External(String)
} derive(Eq, Show, Debug)

///|
struct LocalPathParts {
  absolute : Bool
  components : Array[String]
} derive(Eq, Show, Debug)

///|
pub struct Path {
  kind : PathKind
} derive(Eq, Show, Debug)

///|
fn is_path_separator(ch : Char) -> Bool {
  ch == '/' || ch == '\\'
}

///|
fn has_leading_slash_string(path : String) -> Bool {
  if path.is_empty() {
    return false
  }
  let ch = path.get_char(0).unwrap()
  is_path_separator(ch)
}

///|
fn strip_leading_slashes_string(path : String) -> String {
  let mut start = 0
  while start < path.length() {
    let ch = path.get_char(start).unwrap()
    if !is_path_separator(ch) {
      break
    }
    start += 1
  }
  if start == 0 {
    path
  } else {
    path.unsafe_substring(start~, end=path.length())
  }
}

///|
fn compact_segments(segments : Array[String], count : Int) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<count {
    out.push(segments[i])
  }
  out
}

///|
fn parse_local_path_parts(path : String) -> LocalPathParts {
  let absolute = has_leading_slash_string(path)
  let mut segment = ""
  let segments : Array[String] = []
  let mut segment_count = 0

  for i in 0..<=path.length() {
    let is_end = i == path.length()
    let ch = if is_end { '/' } else { path.get_char(i).unwrap() }
    let is_sep = is_path_separator(ch)
    if !is_sep {
      segment = segment + ch.to_string()
      continue
    }

    if segment.is_empty() || segment == "." {
      segment = ""
      continue
    }

    if segment == ".." {
      if segment_count > 0 && segments[segment_count - 1] != ".." {
        segment_count -= 1
      } else if !absolute {
        if segment_count < segments.length() {
          segments[segment_count] = segment
        } else {
          segments.push(segment)
        }
        segment_count += 1
      }
      segment = ""
      continue
    }

    if segment_count < segments.length() {
      segments[segment_count] = segment
    } else {
      segments.push(segment)
    }
    segment_count += 1
    segment = ""
  }

  LocalPathParts::{
    absolute,
    components: compact_segments(segments, segment_count),
  }
}

///|
fn local_path(absolute : Bool, components : Array[String]) -> Path {
  Path::{ kind: PathKind::Local(absolute, components) }
}

///|
fn external_path(raw : String) -> Path {
  Path::{ kind: PathKind::External(raw) }
}

///|
fn render_local_path(absolute : Bool, components : Array[String]) -> String {
  if components.is_empty() {
    if absolute {
      "/"
    } else {
      ""
    }
  } else {
    let body = components.join("/")
    if absolute {
      "/" + body
    } else {
      body
    }
  }
}

///|
fn is_empty_local_path(absolute : Bool, components : Array[String]) -> Bool {
  !absolute && components.is_empty()
}

///|
fn parent_string(path : String) -> String {
  let mut last_slash = -1
  for i in 0..<path.length() {
    let ch = path.get_char(i).unwrap()
    if is_path_separator(ch) {
      last_slash = i
    }
  }
  if last_slash < 0 {
    ""
  } else if last_slash == 0 {
    "/"
  } else {
    path.unsafe_substring(start=0, end=last_slash)
  }
}

///|
fn copy_components(components : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for component in components {
    out.push(component)
  }
  out
}

///|
fn join_local_components(
  base_absolute : Bool,
  base_components : Array[String],
  child_components : Array[String],
) -> Array[String] {
  let segments = copy_components(base_components)
  let mut count = segments.length()
  for segment in child_components {
    if segment == ".." {
      if count > 0 && segments[count - 1] != ".." {
        count -= 1
      } else if !base_absolute {
        if count < segments.length() {
          segments[count] = segment
        } else {
          segments.push(segment)
        }
        count += 1
      }
      continue
    }

    if segment.is_empty() || segment == "." {
      continue
    }
    if count < segments.length() {
      segments[count] = segment
    } else {
      segments.push(segment)
    }
    count += 1
  }
  compact_segments(segments, count)
}

///|
pub fn Path::new(path : String) -> Path {
  if path.contains(":") {
    external_path(path)
  } else {
    let parsed = parse_local_path_parts(path)
    local_path(parsed.absolute, parsed.components)
  }
}

///|
pub fn Path::as_string(self : Path) -> String {
  match self.kind {
    PathKind::Local(absolute, components) =>
      render_local_path(absolute, components)
    PathKind::External(raw) => raw
  }
}

///|
pub fn Path::to_string(self : Path) -> String {
  self.as_string()
}

///|
pub fn Path::has_leading_slash(self : Path) -> Bool {
  match self.kind {
    PathKind::Local(absolute, _) => absolute
    PathKind::External(raw) => has_leading_slash_string(raw)
  }
}

///|
pub fn Path::strip_leading_slashes(self : Path) -> Path {
  match self.kind {
    PathKind::Local(false, _) => self
    PathKind::Local(true, components) => local_path(false, components)
    PathKind::External(raw) => {
      let stripped = strip_leading_slashes_string(raw)
      if stripped == raw {
        self
      } else {
        Path::new(stripped)
      }
    }
  }
}

///|
pub fn Path::is_relative(self : Path) -> Bool {
  match self.kind {
    PathKind::Local(absolute, components) => !absolute && !components.is_empty()
    PathKind::External(_) => false
  }
}

///|
pub fn Path::parent(self : Path) -> Path {
  match self.kind {
    PathKind::External(raw) => Path::new(parent_string(raw))
    PathKind::Local(absolute, components) =>
      if components.is_empty() {
        local_path(absolute, [])
      } else {
        let out : Array[String] = []
        for i in 0..<(components.length() - 1) {
          out.push(components[i])
        }
        local_path(absolute, out)
      }
  }
}

///|
pub fn Path::join(base : Path, child : Path) -> Path {
  match child.kind {
    PathKind::External(_) => child
    PathKind::Local(child_absolute, child_components) => {
      if is_empty_local_path(child_absolute, child_components) {
        return base
      }
      if child_absolute {
        return child
      }
      match base.kind {
        PathKind::External(raw) =>
          Path::new("\{raw}/\{render_local_path(false, child_components)}")
        PathKind::Local(base_absolute, base_components) =>
          local_path(
            base_absolute,
            join_local_components(
              base_absolute, base_components, child_components,
            ),
          )
      }
    }
  }
}

///|
pub fn Path::normalize(path : String) -> String {
  Path::new(path).as_string()
}
