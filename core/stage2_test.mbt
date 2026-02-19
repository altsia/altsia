///|
fn dummy_loc() -> SourceLoc {
  { start_offset: 0, end_offset: 0, line: 0, column: 0 }
}

///|
fn erase_term_loc(term : Term) -> Term {
  let loc = dummy_loc()
  match term {
    Text(s, _) => Text(s, loc)
    App(name, args, _) => App(name, args.map(erase_term_loc), loc)
    TemplateDefinition(name, params, body, _) =>
      TemplateDefinition(name, params, body.map(erase_term_loc), loc)
    Splice(terms, _) => Splice(terms.map(erase_term_loc), loc)
    Comment(c, _) => Comment(c, loc)
  }
}

///|
fn erase_terms_locs(terms : Array[Term]) -> Array[Term] {
  terms.map(erase_term_loc)
}

///|
test "Stage2 per component" {
  let loc = dummy_loc()
  assert_eq(
    "(song (% dream))" |> Stage1::parse |> Stage2::pass |> erase_terms_locs,
    [App("song", [Comment("dream", loc)], loc)],
  )
  assert_eq("(a) (b)" |> Stage1::parse |> Stage2::pass |> erase_terms_locs, [
    App("a", [], loc),
    App("b", [], loc),
  ])
  assert_eq(
    "(_ Epitaph (% The child was born underground.) (... and the name of the goddess of a rainbow...iris.))"
    |> Stage1::parse
    |> Stage2::pass
    |> erase_terms_locs,
    [
      Splice(
        [
          Text("Epitaph", loc),
          Text(" ", loc),
          Comment("The child was born underground.", loc),
          Text(" ", loc),
          App(
            "...",
            [Text("and the name of the goddess of a rainbow...iris.", loc)],
            loc,
          ),
        ],
        loc,
      ),
    ],
  )
}

///|
test "Stage2 turns quote blocks into text nodes" {
  let source = "(p hello)\n```\nline1\nline2\n```"
  let loc = dummy_loc()
  assert_eq(source |> Stage1::parse |> Stage2::pass |> erase_terms_locs, [
    App(
      "p",
      [Text("hello", loc), Text(" ", loc), Text("line1\nline2\n", loc)],
      loc,
    ),
  ])
}

///|
test "Stage2 turns inline quotes into text nodes" {
  let source = "(p `line one` tail)"
  let loc = dummy_loc()
  assert_eq(source |> Stage1::parse |> Stage2::pass |> erase_terms_locs, [
    App("p", [Text("line one", loc), Text(" ", loc), Text("tail", loc)], loc),
  ])
}

///|
test "Stage2 materializes spacing gaps between app arguments" {
  let source = "(p aa (tex `x^2`).)"
  let loc = dummy_loc()
  assert_eq(source |> Stage1::parse |> Stage2::pass |> erase_terms_locs, [
    App(
      "p",
      [
        Text("aa", loc),
        Text(" ", loc),
        App("tex", [Text("x^2", loc)], loc),
        Text(".", loc),
      ],
      loc,
    ),
  ])
}
