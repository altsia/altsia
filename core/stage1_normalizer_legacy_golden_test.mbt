///|
fn normalize_legacy(source : String, max_width : Int) -> String raise {
  altsia_normalize_raise(source, max_width=max_width)
}

///|
fn parse_legacy_semantics(source : String) -> String raise {
  to_source(Stage1::parse(source))
}

///|
fn assert_same_semantics(left : String, right : String) -> Unit raise {
  assert_eq(parse_legacy_semantics(left), parse_legacy_semantics(right))
}

///|
test "legacy golden keeps semantic equivalence on representative inputs" {
  let source1 =
    #|(% altsia-fmt-off)
    #|
    #|(p   keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(q   normalize   this)
  let normalized1 = normalize_legacy(source1, 80)
  assert_same_semantics(source1, normalized1)

  let source2 = "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))"
  let normalized2 = normalize_legacy(source2, 42)
  assert_same_semantics(source2, normalized2)

  let source3 = "(p (_ 寻)(_ 觅)(_ 冷)(_ 清))"
  let normalized3 = normalize_legacy(source3, 28)
  assert_same_semantics(source3, normalized3)
}

///|
test "legacy golden is idempotent" {
  let source1 = "(p lead (a one two) middle text (b x y) tail)"
  let once1 = normalize_legacy(source1, 26)
  let twice1 = normalize_legacy(once1, 26)
  assert_eq(once1, twice1)

  let source2 =
    #|(% altsia-fmt-off)
    #|
    #|(p    keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(q    normalize this)
  let once2 = normalize_legacy(source2, 80)
  let twice2 = normalize_legacy(once2, 80)
  assert_eq(once2, twice2)
}

///|
test "legacy golden keeps fmt-off area raw while on area can normalize" {
  let source =
    #|(% altsia-fmt-off)
    #|
    #|(p    keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(q    normalize this)
  let normalized = normalize_legacy(source, 80)
  assert_true(normalized.contains("(p    keep   this)"))
  assert_true(normalized.contains("(q normalize this)"))
}

///|
test "legacy golden keeps bytes outside selected range unchanged" {
  let source = "(p   one)\n\n(q    two)\n\n(r   three)"
  let nodes = Stage1::parse(source)
  let mid_loc = nodes[1].loc()
  let normalized = altsia_normalize_range_raise(
    source,
    mid_loc.start_offset,
    mid_loc.end_offset,
    max_width=80,
  )

  let prefix = source.unsafe_substring(start=0, end=mid_loc.start_offset)
  let suffix = source.unsafe_substring(start=mid_loc.end_offset, end=source.length())
  let normalized_prefix = normalized.unsafe_substring(start=0, end=prefix.length())
  assert_eq(normalized_prefix, prefix)

  let suffix_start = normalized.length() - suffix.length()
  let normalized_suffix = normalized.unsafe_substring(start=suffix_start, end=normalized.length())
  assert_eq(normalized_suffix, suffix)
}

