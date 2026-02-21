///|
test "markdown link validator detects external links" {
  assert_true(is_external_link("http://example.com"))
  assert_true(is_external_link("https://example.com"))
  assert_true(is_external_link("www.example.com"))
  assert_true(is_external_link("mailto:a@b.com"))
  assert_true(is_external_link("file://a/b"))
  assert_true(is_external_link("ftp://example.com"))
  assert_true(is_external_link("//cdn.example.com/a.js"))
}

///|
test "markdown link validator detects assets links" {
  assert_true(is_assets_link("assets/logo.png"))
  assert_true(is_assets_link("/assets/logo.png"))
  assert_true(!is_assets_link("asset/logo.png"))
}

///|
test "markdown link validator detects inline typst links" {
  assert_true(is_inline_typst("inline"))
  assert_true(is_inline_typst("inline-demo"))
  assert_true(!is_inline_typst("inlined"))
}

///|
test "markdown link validator detects local links by exclusion rule" {
  assert_true(is_local_link("docs/intro.md"))
  assert_true(is_local_link("../docs/intro.md"))
  assert_true(!is_local_link("https://example.com"))
  assert_true(!is_local_link("assets/logo.png"))
  assert_true(!is_local_link("inline-demo"))
  assert_true(!is_local_link("pkg:entry"))
}
