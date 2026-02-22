///|
test "kodama html term helpers build nested element terms directly" {
  let loc : @core.SourceLoc = {
    start_offset: 0,
    end_offset: 0,
    line: 1,
    column: 1,
  }
  let term = html_element_term(
    "span",
    loc,
    attrs=[html_class_attr(["link", "local"], loc)],
    children=[
      html_element_term(
        "a",
        loc,
        attrs=[
          html_attr("href", "b.alt", loc),
          html_attr("title", "B [b]", loc),
        ],
        children=[html_text_term("B", loc)],
      ),
    ],
  )
  let expected = @core.Term::App(
    "span",
    [
      @core.Term::App(":class", [@core.Term::Text("link local", loc)], loc),
      @core.Term::App(
        "a",
        [
          @core.Term::App(":href", [@core.Term::Text("b.alt", loc)], loc),
          @core.Term::App(":title", [@core.Term::Text("B [b]", loc)], loc),
          @core.Term::Text("B", loc),
        ],
        loc,
      ),
    ],
    loc,
  )
  assert_eq(term, expected)
}

///|
test "kodama html term helpers support named attr terms and key normalization" {
  let loc : @core.SourceLoc = {
    start_offset: 0,
    end_offset: 0,
    line: 1,
    column: 1,
  }
  let term = html_element_term("a", loc, attrs=[
    html_named_attr_term("href", [html_text_term("/x", loc)], loc),
    html_named_attr_term(":title", [html_text_term("X", loc)], loc),
  ])
  guard term is @core.Term::App("a", args, _) else {
    fail("expected a app term")
  }
  guard args
    is [
      @core.Term::App(":href", [@core.Term::Text("/x", _)], _),
      @core.Term::App(":title", [@core.Term::Text("X", _)], _),
    ] else {
    fail("expected normalized named attrs")
  }
}

///|
test "kodama html term helpers can convert pair attrs into named attr terms" {
  let loc : @core.SourceLoc = {
    start_offset: 0,
    end_offset: 0,
    line: 1,
    column: 1,
  }
  let term = html_element_term_from_pairs("img", loc, attrs=[
    ("src", "/a.png"),
    ("alt", "A"),
  ])
  guard term is @core.Term::App("img", args, _) else {
    fail("expected img app term")
  }
  guard args
    is [
      @core.Term::App(":src", [@core.Term::Text("/a.png", _)], _),
      @core.Term::App(":alt", [@core.Term::Text("A", _)], _),
    ] else {
    fail("expected converted pair attrs")
  }
}
