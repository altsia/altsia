///|
test "h renders horizontal space with css custom property" {
  let input = "A(h 2em)B(h 0)C"
  let expected = "<p>A<span class=\"hspace\" aria-hidden=\"true\" style=\"--h:2em;display:inline-block;width:var(--h);height:0;vertical-align:baseline\"></span>B<span class=\"hspace\" aria-hidden=\"true\" style=\"--h:0;display:inline-block;width:var(--h);height:0;vertical-align:baseline\"></span>C</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "h length supports interpolation" {
  let input = "(let gap `1.5ch`)A(h \"(gap)\")B"
  let expected = "<p>A<span class=\"hspace\" aria-hidden=\"true\" style=\"--h:1.5ch;display:inline-block;width:var(--h);height:0;vertical-align:baseline\"></span>B</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "h passes custom property value through" {
  let input = "A(h `var(--gap)`)B"
  let expected = "<p>A<span class=\"hspace\" aria-hidden=\"true\" style=\"--h:var(--gap);display:inline-block;width:var(--h);height:0;vertical-align:baseline\"></span>B</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}
