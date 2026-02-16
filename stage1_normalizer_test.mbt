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
test "Stage1 normalizer canonicalizes quote indentation" {
  let source =
    #|(p)
    #|```
    #|  alpha
    #|    beta
    #|```
  let normalized = altsia_normalize_raise(source)
  let expected =
    #|(p)
    #|```
    #|alpha
    #|  beta
    #|```
  assert_eq(normalized, expected)
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
test "Stage1 normalizer smart-wraps apply definition by max_width" {
  let source = "(p (dup a)(dup b),(dup c)(dup d),(dup e)(dup f)(dup g))"
  let normalized = altsia_normalize_raise(source, max_width=40)
  let expected =
    #|(p
    #|  (dup a) (dup b) , (dup c) (dup d) ,
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
    #|(p lead
    #|  (a one two) middle text
    #|  (b x y) tail )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer packs nested app groups by width" {
  let source = "(p (_ a)(_ b),(_ c)(_ d),(_ e)(_ f)(_ g))"
  let normalized = altsia_normalize_raise(source, max_width=40)
  let expected =
    #|(p
    #|  (_ a) (_ b) , (_ c) (_ d) , (_ e)
    #|  (_ f) (_ g) )
  assert_eq(normalized, expected)
}

///|
test "Stage1 normalizer does not force-wrap long plain-text app" {
  let source = "(p this is a very very very long plain text segment)"
  let normalized = altsia_normalize_raise(source, max_width=20)
  assert_eq(normalized, source)
}

///|
test "Stage1 normalizer exposes structured diagnostics" {
  let diagnostic = match altsia_normalize_diagnostics("oops") {
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
