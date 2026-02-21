///|
test "KoMarkdown converts markdown with inline html and tex together" {
  let source = "mix <span>$x^2$</span> and <i>$$y^2$$</i> done"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p mix (span $x^2$) and (i $$y^2$$) done)")
}

///|
test "KoMarkdown parses inline math before dash text" {
  let source = "$x$-y"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p $x$-y)")
}

///|
test "KoMarkdown parses inline math with markdown special chars inside" {
  let source = "A $f(x)=x^2+t_1x+t_0 \\in k[x], a*b < c$ B"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p A k`f(x)=x^2+t_1x+t_0 \\in k[x], a*b < c` B)")
}

///|
test "KoMarkdown parses block display math fence" {
  let source =
    #|$$
    #|AA
    #|$$
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "$$\nAA\n$$")
}

///|
test "KoMarkdown normalize keeps top-level display math with weak toplevel constraint" {
  let source =
    #|$$
    #|AA
    #|$$
  let altsia = KoMarkdown::to_altsia(source)
  assert_eq(altsia, "(_ $$\nAA\n$$)")
}

///|
test "KoMarkdown parses single-line block display math fence with spaces" {
  let source = "$$ f(x) \\spaces= (x-r)(x+t_1+r) \\spaces\\in F[x] $$"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "kd`f(x) \\spaces= (x-r)(x+t_1+r) \\spaces\\in F[x]`")
}

///|
test "KoMarkdown parses single-line block display math fence without spaces" {
  let source = "$$x^2$$"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "$$x^2$$")
}

///|
test "KoMarkdown parses block html container with markdown body" {
  let source =
    #|<div class="box">
    #|
    #|mix **b** and $x^2$
    #|
    #|</div>
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(div (:class box) (p mix (strong b) and $x^2$))")
}

///|
test "KoMarkdown extracts inline tex math from text token" {
  let source = "tex $x^2$"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex $x^2$)")
}

///|
test "KoMarkdown extracts display tex math from text token" {
  let source = "tex $$x^2$$ tail"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex $$x^2$$ tail)")
}

///|
test "KoMarkdown can disable katex conversion for inline math" {
  let source = "tex $x^2$ and $$y^2$$ tail"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: NeverApp,
  })
  assert_eq(altsia, "(p tex $x^2$ and $$y^2$$ tail)")
}

///|
test "KoMarkdown can disable katex conversion for metadata values" {
  let source =
    #|---
    #|equation: tex $x^2$
    #|---
    #|# Title
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: NeverApp,
  })
  let expected =
    #|(metadata (:equation tex $x^2$))
    #|
    #|(h1 Title)
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown can disable katex conversion for block math fence" {
  let source =
    #|$$
    #|AA
    #|$$
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: NeverApp,
  })
  assert_eq(altsia, "$$\nAA\n$$")
}

///|
test "KoMarkdown can auto-convert katex by parentheses for inline math" {
  let source = "a $x^2$ b $f(x)$ c"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: AppWhenHasParens,
  })
  assert_eq(altsia, "(p a $x^2$ b k`f(x)` c)")
}

///|
test "KoMarkdown can auto-convert katex by parentheses for display math" {
  let source = "a $$x^2$$ b $$f(x)$$ c"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: AppWhenHasParens,
  })
  assert_eq(altsia, "(p a $$x^2$$ b kd`f(x)` c)")
}

///|
test "KoMarkdown always converts macro definition math to app form in never mode" {
  let source = "a $\\def\\foo{x}$ b"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: NeverApp,
  })
  assert_eq(altsia, "(p a k`\\def\\foo{x}` b)")
}

///|
test "KoMarkdown always converts macro definition math to app form in auto mode" {
  let source = "a $\\newcommand{\\foo}{x}$ b"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: AppWhenHasParens,
  })
  assert_eq(altsia, "(p a k`\\newcommand{\\foo}{x}` b)")
}

///|
test "KoMarkdown emits standalone macro definition math without paragraph wrapper" {
  let source = "$\\def\\foo{x}$"
  let altsia = KoMarkdown::to_altsia(source, normalize=false, options={
    convert_katex: NeverApp,
  })
  assert_eq(altsia, "k`\\def\\foo{x}`")
}

///|
test "KoMarkdown keeps brace-nested tex body intact" {
  let source = "tex $\\frac{a}{b}$."
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p tex $\\frac{a}{b}$.)")
}

///|
test "KoMarkdown parses math in headings and list items" {
  let source =
    #|# Title $x^2$
    #|
    #|- item $y$
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  let expected =
    #|(h1 Title $x^2$)
    #|
    #|(ul (li item $y$))
  assert_eq(altsia, expected)
}

///|
test "KoMarkdown parses table cells and math inside them" {
  let source =
    #|| lhs | rhs |
    #|| --- | --- |
    #|| $x^2$ | $$y^2$$ |
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(
    altsia, "(table (tr (th lhs) (th rhs)) (tr (td $x^2$) (td $$y^2$$)))",
  )
}

///|
test "KoMarkdown keeps dollar-delimited text form when auto mode does not use app" {
  let source = "a $ x$ b $x $ c $x$2 d $x$ e"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p a $ x$ b $x $ c $x$2 d $x$ e)")
}

///|
test "KoMarkdown treats unescaped dollar as math delimiter regardless of spaces or trailing digits" {
  let source = "a $ f(x)$ b $f(x) $ c $f(x)$2 d"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p a k` f(x)` b k`f(x) ` c k`f(x)`2 d)")
}

///|
test "KoMarkdown ignores escaped dollar opener for math start" {
  let source = "price \\$x$ and $y$"
  let altsia = KoMarkdown::to_altsia(source, normalize=false)
  assert_eq(altsia, "(p price \\$x$ and $y$)")
}
