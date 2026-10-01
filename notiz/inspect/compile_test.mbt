///|
test "compile html errors on empty frontmatter lang" {
  let _result = @notiz.compile("---\nlang:\n---\n\n= Head\n", target=Html) catch {
    _ => return
  }
  @test.fail("expected compile to fail")
}

///|
test "compile html errors on unknown frontmatter paper" {
  let _result = @notiz.compile("---\npaper: A3\n---\n\n= Head\n", target=Html) catch {
    _ => return
  }
  @test.fail("expected compile to fail")
}

///|
test "compile html uses frontmatter paper" {
  let b5 = @notiz.compile("---\npaper: b5\n---\n\n= Head\n", target=Html) catch {
    _ => @test.fail("expected compile to succeed")
  }
  let a4 = @notiz.compile("= Head\n", target=Html) catch {
    _ => @test.fail("expected compile to succeed")
  }
  assert_true(b5 != a4)
}

///|
test "compile html-canonical expands macros and injects katex" {
  let html = @notiz.compile(
    "The solution of $\\def\\foo{x}\\foo$ is $x^2$.\n",
    target=@notiz.HtmlCanonical,
  ) catch {
    _ => @test.fail("expected compile to succeed")
  }
  @test.assert_eq(html.contains("$x$"), true)
  @test.assert_eq(html.contains("katex.min.js"), true)
  @test.assert_eq(html.contains("$x^2$"), true)
}
