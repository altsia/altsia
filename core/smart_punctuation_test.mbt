///|
fn smart_punctuation_html(source : String) -> String raise {
  source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> Stage3::pass
  |> SmartPunctuation::pass
  |> Html::from
  |> Html::to_string
}

///|
fn smart_punctuation_html_with_extern(source : String) -> String raise {
  let rewriter = empty_extern_api.to_rewriter()
  source
  |> Stage1::parse
  |> Stage2::pass
  |> Stage2Etale::expand_program
  |> (terms => Stage2Extern::rewrite_apps(terms, rewriter))
  |> Stage3::pass
  |> SmartPunctuation::pass
  |> Html::from
  |> Html::to_string
}

///|
test "SmartPunctuation transforms common markdown-style punctuation in text" {
  let html = smart_punctuation_html("(p a---b c--d e...f)")
  assert_true(html.contains("a—b"))
  assert_true(html.contains("c–d"))
  assert_true(html.contains("e…f"))
}

///|
test "SmartPunctuation skips protected code and katex tags" {
  let html = smart_punctuation_html("(p (code x--y) (k z--w) u--v)")
  assert_true(html.contains("<code>x--y</code>"))
  assert_true(html.contains("<k>z--w</k>"))
  assert_true(html.contains("u–v"))
}

///|
test "SmartPunctuation skips extern result app content" {
  let html = smart_punctuation_html_with_extern("(p (k x--y) u--v)")
  assert_true(html.contains("x--y"))
  assert_true(html.contains("u–v"))
}
