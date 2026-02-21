///|
pub(all) struct NamedAppArg {
  name : Name
  values : Array[Term]
  loc : SourceLoc
} derive(Eq, Show, Debug)

///|
pub(all) struct SplitAppArgs {
  named : Array[NamedAppArg]
  positional : Array[Term]
} derive(Eq, Show, Debug)

///|
fn stage2_extern_is_layout_gap_space(term : Term) -> Bool {
  match term {
    Text(" ", loc) => loc.start_offset == loc.end_offset
    _ => false
  }
}

///|
fn stage2_extern_strip_layout_gap_spaces(args : Array[Term]) -> Array[Term] {
  let result = []
  for arg in args {
    if !stage2_extern_is_layout_gap_space(arg) {
      result.push(arg)
    }
  }
  result
}

///|
pub fn Stage2Extern::split_app_args(
  args : Array[Term],
  strip_layout_gap_spaces? : Bool = true,
) -> SplitAppArgs {
  let normalized_args = if strip_layout_gap_spaces {
    stage2_extern_strip_layout_gap_spaces(args)
  } else {
    args
  }
  let named : Array[NamedAppArg] = []
  let positional : Array[Term] = []
  for arg in normalized_args {
    match arg {
      App(name, values, loc) if name.strip_prefix(":") is Some(_) =>
        named.push(NamedAppArg::{ name, values, loc })
      _ => positional.push(arg)
    }
  }
  SplitAppArgs::{ named, positional }
}
