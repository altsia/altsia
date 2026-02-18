///|
fn parse_doc_semantics(source : String) -> String raise {
  to_source(Stage1::parse(source))
}

///|
fn normalize_doc_candidate(source : String, max_width : Int) -> String raise {
  // Current placeholder: candidate doc formatter shares normalizer implementation.
  // Future pretty-printer can replace this function without changing tests.
  altsia_normalize_raise(source, max_width=max_width)
}

///|
fn normalize_legacy_baseline(source : String, max_width : Int) -> String raise {
  altsia_normalize_raise(source, max_width=max_width)
}

///|
fn assert_doc_and_legacy_semantics(source : String, max_width : Int) -> Unit raise {
  let doc_output = normalize_doc_candidate(source, max_width)
  let legacy_output = normalize_legacy_baseline(source, max_width)
  assert_eq(parse_doc_semantics(doc_output), parse_doc_semantics(legacy_output))
}

///|
test "doc golden template wrap target style" {
  let source = "(λ card (title subtitle) (div class card-body) (p title) (p subtitle) (footer note))"
  let output = normalize_doc_candidate(source, 42)
  let expected =
    #|(λ card (title subtitle)
    #|  (div class card-body)
    #|  (p title)
    #|  (p subtitle)
    #|  (footer note) )
  assert_eq(output, expected)
  assert_doc_and_legacy_semantics(source, 42)
}

///|
test "doc golden general app wrap target style" {
  let source = "(p lead (a one two) middle text (b x y) tail)"
  let output = normalize_doc_candidate(source, 26)
  let expected =
    #|(p lead
    #|  (a one two) middle text
    #|  (b x y) tail )
  assert_eq(output, expected)
  assert_doc_and_legacy_semantics(source, 26)
}

///|
test "doc golden nested group packing target style" {
  let source = "(p (_ a)(_ b),(_ c)(_ d),(_ e)(_ f)(_ g))"
  let output = normalize_doc_candidate(source, 40)
  let expected =
    #|(p
    #|  (_ a) (_ b) , (_ c) (_ d) , (_ e)
    #|  (_ f) (_ g) )
  assert_eq(output, expected)
  assert_doc_and_legacy_semantics(source, 40)
}

