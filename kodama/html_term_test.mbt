///|
test "kodama html term builder lowers nested elements to core terms" {
  let loc : @core.SourceLoc = { start_offset: 0, end_offset: 0, line: 1, column: 1 }
  let node = html_element_node(
    "span",
    attrs=[html_class_attr(["link", "local"])],
    children=[
      html_element_node(
        "a",
        attrs=[html_attr("href", "b.alt"), html_attr("title", "B [b]")],
        children=[html_text_node("B")],
      ),
    ],
  )
  let term = node.to_term(loc)
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
test "kodama html term builder accepts attrs with or without colon prefix" {
  let loc : @core.SourceLoc = { start_offset: 0, end_offset: 0, line: 1, column: 1 }
  let node = html_element_node(
    "a",
    attrs=[html_attr("href", "/x"), html_attr(":title", "X")],
  )
  let term = node.to_term(loc)
  guard term is @core.Term::App("a", args, _) else {
    fail("expected a app term")
  }
  guard args is [
    @core.Term::App(":href", [@core.Term::Text("/x", _)], _),
    @core.Term::App(":title", [@core.Term::Text("X", _)], _),
  ] else {
    fail("expected normalized attr terms")
  }
}
