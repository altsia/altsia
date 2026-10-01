///|
/// TeX math spacing rules. Based on KaTeX spacingData.ts and TeXbook Ch.18.
///
/// This module provides backend-agnostic spacing logic: 8x8 atom spacing tables,
/// bin atom cancellation, and a join helper. Concrete space representations are
/// supplied via `SpacingSpec`.

///|
/// Concrete space representations for a rendering backend.
/// Different backends (unicode text, HTML/CSS, LaTeX) provide their own spec.
pub(all) struct SpacingSpec {
  thick : String
  medium : String
  thin : String
  operator : String
} derive(Eq)

///|
/// Converts AtomFamily to the corresponding spacing type string.
pub fn atom_family_name(family : @katex.AtomFamily) -> String {
  match family {
    @katex.AtomFamily::Mord => "mord"
    @katex.AtomFamily::Mop => "mop"
    @katex.AtomFamily::Mbin => "mbin"
    @katex.AtomFamily::Mrel => "mrel"
    @katex.AtomFamily::Mopen => "mopen"
    @katex.AtomFamily::Mclose => "mclose"
    @katex.AtomFamily::Mpunct => "mpunct"
    @katex.AtomFamily::Minner => "minner"
  }
}

///|
/// Normal (display/text) spacing table between atom types.
fn normal_spacing(left : String, right : String, spec : SpacingSpec) -> String? {
  match (left, right) {
    ("mord", "mop") | ("mord", "mbig") => Some(spec.thin)
    ("mord", "mbin") => Some(spec.medium)
    ("mord", "mrel") => Some(spec.thick)
    ("mord", "minner") => Some(spec.thin)
    ("mop", "mord") => Some(spec.operator)
    ("mop", "mop") | ("mop", "mbig") => Some(spec.operator)
    ("mop", "mrel") => Some(spec.thick)
    ("mop", "minner") => Some(spec.thin)
    ("mbig", "mord")
    | ("mbig", "mop")
    | ("mbig", "mopen")
    | ("mbig", "minner") => Some(spec.medium)
    ("mbig", "mbin") => Some(spec.medium)
    ("mbig", "mrel") => Some(spec.thick)
    ("mbig", "mclose") | ("mbig", "mpunct") => Some(spec.thin)
    ("mbin", "mord") => Some(spec.medium)
    ("mbin", "mop") | ("mbin", "mbig") => Some(spec.medium)
    ("mbin", "mopen") => Some(spec.medium)
    ("mbin", "minner") => Some(spec.medium)
    ("mrel", "mord") => Some(spec.thick)
    ("mrel", "mop") | ("mrel", "mbig") => Some(spec.thick)
    ("mrel", "mopen") => Some(spec.thick)
    ("mrel", "minner") => Some(spec.thick)
    ("mclose", "mop") | ("mclose", "mbig") => Some(spec.thin)
    ("mclose", "mbin") => Some(spec.medium)
    ("mclose", "mrel") => Some(spec.thick)
    ("mclose", "minner") => Some(spec.thin)
    ("mpunct", "mord") => Some(spec.thin)
    ("mpunct", "mop") | ("mpunct", "mbig") => Some(spec.thin)
    ("mpunct", "mrel") => Some(spec.thick)
    ("mpunct", "mopen") => Some(spec.thin)
    ("mpunct", "mclose") => Some(spec.thin)
    ("mpunct", "mpunct") => Some(spec.thin)
    ("mpunct", "minner") => Some(spec.thin)
    ("minner", "mord") => Some(spec.thin)
    ("minner", "mop") | ("minner", "mbig") => Some(spec.thin)
    ("minner", "mbin") => Some(spec.medium)
    ("minner", "mrel") => Some(spec.thick)
    ("minner", "mopen") => Some(spec.thin)
    ("minner", "mpunct") => Some(spec.thin)
    ("minner", "minner") => Some(spec.thin)
    _ => None
  }
}

///|
/// Tight (script/scriptscript) spacing table.
fn tight_spacing(left : String, right : String, spec : SpacingSpec) -> String? {
  match (left, right) {
    ("mord", "mop") => Some(spec.thin)
    ("mop", "mord") => Some(spec.thin)
    ("mop", "mop") => Some(spec.thin)
    ("mbig", "mord") | ("mbig", "mop") | ("mbig", "minner") => Some(spec.thin)
    ("mclose", "mop") => Some(spec.thin)
    ("minner", "mop") => Some(spec.thin)
    _ => None
  }
}

///|
/// Look up spacing between two atom types.
pub fn math_spacing(
  left_type : String,
  right_type : String,
  tight : Bool,
  spec : SpacingSpec,
) -> String? {
  if tight {
    tight_spacing(left_type, right_type, spec)
  } else {
    normal_spacing(left_type, right_type, spec)
  }
}

///|
/// A renderable atom with its math class and baseline info.
pub(all) struct SpacableItem {
  atom_type : String?
  text : String
  baseline : Int
}

///|
/// True when a type to the left of a binary atom cancels its binary spacing.
/// TeXbook Rules 5-6.
fn cancels_left_of_bin(ty : String) -> Bool {
  match ty {
    "leftmost" | "mbin" | "mopen" | "mrel" | "mop" | "mpunct" | "mbig" => true
    _ => false
  }
}

///|
/// True when a type to the right of a binary atom cancels its binary spacing.
fn cancels_right_of_bin(ty : String) -> Bool {
  match ty {
    "rightmost" | "mrel" | "mclose" | "mpunct" => true
    _ => false
  }
}

///|
/// Apply bin cancellation: Mbin atoms become Mord in certain contexts.
pub fn cancel_bin_atoms(items : Array[SpacableItem]) -> Array[SpacableItem] {
  let n = items.length()
  guard n != 0 else { return items }

  // Handle leftmost boundary
  if items[0].atom_type is Some("mbin") {
    items[0] = { ..items[0], atom_type: Some("mord"), }
  }

  // Handle adjacent pairs
  for i = 1; i < n; i = i + 1 {
    let prev_ty = items[i - 1].atom_type
    let curr_ty = items[i].atom_type
    match (prev_ty, curr_ty) {
      (Some("mbin"), Some(right)) =>
        if cancels_right_of_bin(right) {
          items[i - 1] = { ..items[i - 1], atom_type: Some("mord"), }
        }
      (Some(left), Some("mbin")) =>
        if cancels_left_of_bin(left) {
          items[i] = { ..items[i], atom_type: Some("mord"), }
        }
      _ => ()
    }
  }

  // Handle rightmost boundary
  if n >= 1 && items[n - 1].atom_type is Some("mbin") {
    items[n - 1] = { ..items[n - 1], atom_type: Some("mord"), }
  }

  items
}

///|
/// Join spacable items into a string, inserting spacing between adjacent
/// non-space atoms according to the given `SpacingSpec`.
pub fn join_with_spacing(
  items : Array[SpacableItem],
  tight : Bool,
  spec : SpacingSpec,
) -> String {
  let n = items.length()
  guard n > 0 else { return "" }
  guard n > 1 else { return items[0].text }

  let mut result : String = items[0].text
  for i = 1; i < n; i = i + 1 {
    let prev = items[i - 1]
    let curr = items[i]
    match (prev.atom_type, curr.atom_type) {
      (Some(left), Some(right)) =>
        match math_spacing(left, right, tight, spec) {
          Some(space) => result = result + space + curr.text
          None => result = result + curr.text
        }
      _ => result = result + curr.text
    }
  }
  result
}
