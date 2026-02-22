///|
pub(all) struct NamedAppArg {
  name : Name
  values : Array[Term]
  loc : SourceLoc
} derive(Eq, Show, Debug)

///|
pub(all) struct SplitAppArgs {
  named : Map[Name, NamedAppArg]
  named_entries : Array[NamedAppArg]
  positional : Array[Term]
} derive(Eq, Show, Debug)

///|
pub type Stage2Chisel

///|
fn stage2_chisel_normalize_named_arg_key(name : Name) -> Name {
  if name.has_prefix(":") {
    name
  } else {
    ":\{name}"
  }
}

///|
fn Stage2Chisel::is_layout_gap_space(term : Term) -> Bool {
  match term {
    Text(" ", loc) => loc.start_offset == loc.end_offset
    _ => false
  }
}

///|
fn Stage2Chisel::strip_layout_gap_spaces(args : Array[Term]) -> Array[Term] {
  let result = []
  for arg in args {
    if !Stage2Chisel::is_layout_gap_space(arg) {
      result.push(arg)
    }
  }
  result
}

///|
/// Split app arguments into:
/// - named args: `(:name ...)`
/// - positional args: all others
///
/// `strip_layout_gap_spaces` controls whether parser-inserted layout gap nodes
/// (`Text(" ", loc)` where `loc.start_offset == loc.end_offset`) are removed
/// before splitting.
///
/// Keep it `true` (default) for semantic processing.
/// Set it to `false` when you need to preserve original layout gaps.
pub fn Stage2Chisel::split_app_args(
  args : Array[Term],
  strip_layout_gap_spaces? : Bool = true,
) -> SplitAppArgs {
  let normalized_args = if strip_layout_gap_spaces {
    Stage2Chisel::strip_layout_gap_spaces(args)
  } else {
    args
  }

  let named : Map[Name, NamedAppArg] = Map::new()
  let named_entries : Array[NamedAppArg] = []
  let positional : Array[Term] = []
  for arg in normalized_args {
    match arg {
      App(name, values, loc) if name.strip_prefix(":") is Some(_) => {
        let named_arg = NamedAppArg::{ name, values, loc }
        named_entries.push(named_arg)
        // Keep first occurrence for key-based lookup.
        if named.get(name) is None {
          named[name] = named_arg
        }
      }
      _ => positional.push(arg)
    }
  }
  SplitAppArgs::{ named, named_entries, positional }
}

///|
/// Return the first named argument with key `name`.
///
/// `name` accepts either `foo` or `:foo`.
pub fn SplitAppArgs::get_named(
  split : SplitAppArgs,
  name : Name,
) -> NamedAppArg? {
  split.named.get(stage2_chisel_normalize_named_arg_key(name))
}
