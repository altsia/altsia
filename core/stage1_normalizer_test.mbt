///|
fn assert_same_normalizer_semantics(
  left : String,
  right : String,
) -> Unit raise {
  assert_eq(Stage1::parse_semantics(left), Stage1::parse_semantics(right))
}

///|
test "Stage1 normalizer canonicalizes top-level spacing" {
  let source =
    #|  (p hello)   
    #|
    #|   (q world)  
  let normalized = altsia_normalize_raise(source)
  assert_eq(normalized, "(p hello)\n\n(q world)")
}

///|
test "Stage1 normalizer keeps top-level display math with boundary blank lines" {
  let source = "kd`x^2`"
  let normalized = altsia_normalize_raise(source)
  assert_eq(normalized, "\n\nkd`x^2`\n\n")
}

///|
test "Stage1 normalizer keeps inline math in normal inline flow" {
  let source = "(p alpha k`x^2` omega)"
  let normalized = altsia_normalize_raise(source)
  assert_eq(normalized, source)
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer treats generic app quote-inline sugar as inline" {
  let source = "(p alpha f`verylong` omega)"
  let normalized = altsia_normalize_raise(source, max_width=14)
  assert_eq(normalized, source)
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer places display math with blank lines inside app" {
  let source = "(proof intro kd`x^2` outro)"
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|(proof intro
    #|
    #|  kd`x^2`
    #|
    #|  outro )
  assert_eq(normalized, expected)
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer keeps multiline kd content unchanged inside app" {
  let source = "(proof intro kd`line1\nline2` outro)"
  let normalized = altsia_normalize_raise(source)
  assert_true(normalized.contains("kd`line1\nline2`"))
  assert_true(!normalized.contains("kd`line1\n  line2`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer keeps multiline kd content with inner indentation" {
  let source = "(proof intro kd`  a+b\n    c+d\n  e` outro)"
  let normalized = altsia_normalize_raise(source)
  assert_true(normalized.contains("kd`  a+b\n    c+d\n  e`"))
  assert_true(!normalized.contains("kd`  a+b\n      c+d\n  e`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer keeps multiline kd content unchanged in template wrap" {
  let source = "(λ t (x) (proof intro kd`line1\n  line2` outro) (footer x))"
  let normalized = altsia_normalize_raise(source, max_width=34)
  assert_true(normalized.contains("kd`line1\n  line2`"))
  assert_true(!normalized.contains("kd`line1\n    line2`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer canonical app uses quote-inline sugar" {
  let source = "(k `x^2`)"
  let normalized = altsia_normalize_raise(source)
  assert_eq(normalized, "k`x^2`")
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer canonical app uses quote-block sugar" {
  let source =
    #|(kd)
    #|```
    #|AA
    #|```
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|kd```
    #|AA
    #|```
  assert_eq(normalized, expected)
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer canonicalizes quote indentation" {
  let source =
    #|(p)
    #|```
    #|  alpha
    #|    beta
    #|```
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|p```
    #|alpha
    #|  beta
    #|```
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer keeps multiline inline quote content unchanged" {
  let source = "(p (left) `aa\nbb` (right))"
  let normalized = altsia_normalize_raise(source, max_width=12)
  assert_true(normalized.contains("`aa\nbb`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer keeps multiline inline quote content in template wrap" {
  let source = "(λ t (x) (p `aa\nbb` (x)) (footer x))"
  let normalized = altsia_normalize_raise(source, max_width=20)
  assert_true(normalized.contains("`aa\nbb`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer still wraps app with multiline inline quote by width" {
  let source = "(p (left long text) `aa\nbb` (right long text))"
  let normalized = altsia_normalize_raise(source, max_width=22)
  assert_true(normalized.contains("\n"))
  assert_true(normalized.contains("`aa\nbb`"))
  assert_true(!normalized.contains("`aa\n  bb`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer still wraps template with multiline inline quote by width" {
  let source = "(λ t (x) (p (left long text) `aa\nbb` (x)) (footer x) (tail x))"
  let normalized = altsia_normalize_raise(source, max_width=24)
  assert_true(normalized.contains("\n"))
  assert_true(normalized.contains("`aa\nbb`"))
  assert_true(!normalized.contains("`aa\n  bb`"))
  assert_same_normalizer_semantics(source, normalized)
}

///|
test "Stage1 normalizer supports altsia-fmt-skip at top level" {
  let source =
    #|(% altsia-fmt-skip)
    #|
    #|(  p   keep   this  )
    #|
    #|(q    normalize   this)
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|(% altsia-fmt-skip)
    #|
    #|(  p   keep   this  )
    #|
    #|(q normalize   this)
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer supports altsia-fmt-skip inside app" {
  let source = "(p (% altsia-fmt-skip) (  q   keep  this ) (r    normalize this))"
  let normalized = altsia_normalize_raise(source)
  assert_eq(
    normalized, "(p (% altsia-fmt-skip) (  q   keep  this ) (r normalize this))",
  )
}

///|
test "Stage1 normalizer supports altsia-fmt-off/on at top level" {
  let source =
    #|(% altsia-fmt-off)
    #|
    #|(  p   keep   this  )
    #|
    #|(q    also   keep)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(r    normalize this)
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|(% altsia-fmt-off)
    #|
    #|(  p   keep   this  )
    #|
    #|(q    also   keep)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(r normalize this)
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer supports altsia-fmt-off/on inside app" {
  let source = "(p (% altsia-fmt-off) (  q   keep  this ) (  s   keep2 ) (% altsia-fmt-on) (r    normalize this))"
  let normalized = altsia_normalize_raise(source, max_width=200)
  assert_eq(
    normalized, "(p (% altsia-fmt-off) (  q   keep  this ) (  s   keep2 ) (% altsia-fmt-on) (r normalize this))",
  )
}

///|
test "Stage1 normalizer applies nested on/off without changing parent off state" {
  let source =
    #|(% altsia-fmt-off)
    #|
    #|(p (% altsia-fmt-on) (r    normalize this) (% altsia-fmt-off) (  s   keep   this ))
    #|
    #|(u    still   keep)
  let normalized = altsia_normalize_raise(source, max_width=200)
  let expected =
    #|(% altsia-fmt-off)
    #|
    #|(p (% altsia-fmt-on) (r normalize this) (% altsia-fmt-off) (  s   keep   this ))
    #|
    #|(u    still   keep)
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer smart-wraps template definition by max_width" {
  let source = "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))"
  let normalized = altsia_normalize_raise(source, max_width=42)
  let expected =
    #|(λ card (title subtitle)
    #|  (div class card-body)
    #|  (p title)
    #|  (p subtitle)
    #|  (footer note) )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer smart-wraps template definition by max_width II" {
  let source = "(λ inline-section ((taxon) (title) (content)) (section (details (:open) (:class kira) (summary (header (h1 (span (:taxon) (taxon)) (title)) ) ) (content) ) ) )"
  let normalized = altsia_normalize_raise(source, max_width=42)
  let expected =
    #|(λ inline-section ((taxon) (title) (content))
    #|  (section
    #|    (details (:open) (:class kira)
    #|      (summary
    #|        (header
    #|          (h1 (span (:taxon) (taxon)) (title)) ) )
    #|      (content) ) ) )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer smart-wraps apply definition by max_width" {
  let source = "(p (dup a)(dup b),(dup c)(dup d),(dup e)(dup f)(dup g))"
  let normalized = altsia_normalize_raise(source, max_width=40)
  let expected =
    #|(p (dup a) (dup b),(dup c) (dup d),
    #|  (dup e) (dup f) (dup g) )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer keeps template in one line when width is enough" {
  let source = "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))"
  let normalized = altsia_normalize_raise(source, max_width=200)
  assert_eq(
    normalized, "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))",
  )
}

///|
test "Stage1 normalizer smart-wraps general app before nested apps" {
  let source = "(p lead (a one two) middle text (b x y) tail)"
  let normalized = altsia_normalize_raise(source, max_width=26)
  let expected =
    #|(p lead (a one two)
    #|  middle text (b x y) tail )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer packs nested app groups by width with AST indent" {
  let source = "(p (_ a)(_ b),(_ c)(_ d),(_ e)(_ f)(_ g))"
  let normalized = altsia_normalize_raise(source, max_width=40)
  let expected =
    #|(p (_ a) (_ b),(_ c) (_ d),(_ e) (_ f)
    #|  (_ g) )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer does not force-wrap long plain-text app" {
  let source = "(p this is a very very very long plain text segment)"
  let normalized = altsia_normalize_raise(source, max_width=20)
  assert_eq(normalized, source)
}

///|
test "Stage1 normalizer counts CJK display width as double" {
  let latin = altsia_normalize_raise("(p (_ a)(_ b)(_ c)(_ d))", max_width=28)
  assert_eq(latin, "(p (_ a) (_ b) (_ c) (_ d))")

  let cjk = altsia_normalize_raise(
    "(p (_ 寻)(_ 觅)(_ 冷)(_ 清))",
    max_width=28,
  )
  let expected =
    #|(p (_ 寻) (_ 觅) (_ 冷)
    #|  (_ 清) )
  assert_eq(cjk, expected)
}

///|
test "Stage1 normalizer keeps semantic equivalence on representative inputs" {
  let source1 =
    #|(% altsia-fmt-off)
    #|
    #|(p   keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(q   normalize   this)
  let normalized1 = altsia_normalize_raise(source1, max_width=80)
  assert_same_normalizer_semantics(source1, normalized1)

  let source2 = "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))"
  let normalized2 = altsia_normalize_raise(source2, max_width=42)
  assert_same_normalizer_semantics(source2, normalized2)

  let source3 = "(p (_ 寻)(_ 觅)(_ 冷)(_ 清))"
  let normalized3 = altsia_normalize_raise(source3, max_width=28)
  assert_same_normalizer_semantics(source3, normalized3)
}

///|
test "Stage1 normalizer is idempotent" {
  let source1 = "(p lead (a one two) middle text (b x y) tail)"
  let once1 = altsia_normalize_raise(source1, max_width=26)
  let twice1 = altsia_normalize_raise(once1, max_width=26)
  assert_eq(once1, twice1)

  let source2 =
    #|(% altsia-fmt-off)
    #|
    #|(p    keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(q    normalize this)
  let once2 = altsia_normalize_raise(source2, max_width=80)
  let twice2 = altsia_normalize_raise(once2, max_width=80)
  assert_eq(once2, twice2)
}

///|
test "Stage1 normalizer exposes structured diagnostics" {
  let diagnostic = match
    altsia_normalize_diagnostics("oops", weak_toplevel_constraint=false) {
    Err(errors) => {
      guard !errors.is_empty() else {
        fail("expected at least one normalize error")
      }
      errors[0]
    }
    Ok(_) => fail("expected normalize diagnostics error")
  }
  assert_eq(diagnostic.code, "stage1.unexpected-top-level-token")
  assert_eq(diagnostic.phase, "stage1.parse")
  guard diagnostic.loc is Some(loc) else {
    fail("expected Stage1 normalize loc")
  }
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 1)
  guard diagnostic.source_excerpt is Some(excerpt) else {
    fail("expected Stage1 normalize source excerpt")
  }
  assert_true(excerpt.contains("oops"))
}

///|
test "Stage1 range normalize only rewrites selected top-level node" {
  let source = "(p   one)\n\n(q    two)\n\n(r   three)"
  let nodes = Stage1::parse(source)
  let loc = nodes[1].loc()
  let normalized = altsia_normalize_range_raise(
    source,
    loc.start_offset,
    loc.end_offset,
  )
  let expected = "(p   one)\n\n(q two)\n\n(r   three)"
  assert_eq(normalized, expected)
}

///|
test "Stage1 range normalize selects node on partial overlap" {
  let source = "(p   one)\n\n(q    two)\n\n(r   three)"
  let nodes = Stage1::parse(source)
  let loc = nodes[1].loc()
  let normalized = altsia_normalize_range_raise(
    source,
    loc.start_offset + 2,
    loc.start_offset + 5,
  )
  let expected = "(p   one)\n\n(q two)\n\n(r   three)"
  assert_eq(normalized, expected)
}

///|
test "Stage1 range normalize inherits fmt state before range" {
  let source =
    #|(% altsia-fmt-off)
    #|
    #|(q    keep   this)
    #|
    #|(% altsia-fmt-on)
    #|
    #|(r    normalize this)
  let nodes = Stage1::parse(source)
  let loc = nodes[1].loc()
  let normalized = altsia_normalize_range_raise(
    source,
    loc.start_offset,
    loc.end_offset,
    max_width=200,
  )
  assert_eq(normalized, source)
}

///|
test "Stage1 range normalize leaves source unchanged for empty range" {
  let source = "(p   one)\n\n(q    two)"
  let nodes = Stage1::parse(source)
  let empty_offset = nodes[0].loc().end_offset
  let normalized = altsia_normalize_range_raise(
    source, empty_offset, empty_offset,
  )
  assert_eq(normalized, source)
}

///|
test "Stage1 range normalize exposes structured invalid-range diagnostics" {
  let source = "(p hi)"
  let diagnostic = match altsia_normalize_range_diagnostics(source, 5, 1) {
    Err(errors) => {
      guard !errors.is_empty() else {
        fail("expected at least one range normalize error")
      }
      errors[0]
    }
    Ok(_) => fail("expected range normalize diagnostics error")
  }
  assert_eq(diagnostic.code, "stage1.normalize.invalid-range")
  assert_eq(diagnostic.phase, "stage1.normalize")
  guard diagnostic.loc is Some(loc) else {
    fail("expected Stage1 range normalize loc")
  }
  assert_eq(loc.line, 1)
  assert_eq(loc.column, 6)
  guard diagnostic.source_excerpt is Some(excerpt) else {
    fail("expected Stage1 range normalize source excerpt")
  }
  assert_true(excerpt.contains("(p hi)"))
}
