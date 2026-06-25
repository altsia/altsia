///|
fn render_html_result(source : String) -> Result[String, String] {
  match to_html(source) {
    Ok(html) => Ok(html)
    Err(diagnostic) => Err(diagnostic.render())
  }
}

///|
fn render_html_document_result(
  source : String,
  options? : HtmlDocumentOptions,
) -> Result[String, String] {
  match to_html_document(source, options) {
    Ok(html) => Ok(html)
    Err(diagnostic) => Err(diagnostic.render())
  }
}

///|
fn parse_doc(source : String) -> @core.Document {
  match @core.parse(source) {
    Ok(doc) => doc
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn collect_env(doc : @core.Document) -> @core.CompileEnv {
  match @core.collect_bindings(doc) {
    Ok(env) => env
    Err(diagnostic) => abort(diagnostic.render())
  }
}

///|
fn render_fragment_result(
  doc : @core.Document,
  env? : @core.CompileEnv,
  options? : CompileOptions,
) -> Result[String, String] {
  let result = match (env, options) {
    (Some(env), Some(options)) => compile_fragment(doc, env~, options~)
    (Some(env), None) => compile_fragment(doc, env~)
    (None, Some(options)) => compile_fragment(doc, options~)
    (None, None) => compile_fragment(doc)
  }
  match result {
    Ok(nodes) => Ok(@sexp.render_html_fragment(nodes))
    Err(diagnostic) => Err(diagnostic.render())
  }
}

///|
test "renders paragraphs and inline sugar" {
  let input =
    #|Hello *world*.
    #|Still same paragraph.
    #|
    #|Next **one**.
  let expected = "<p>Hello <em>world</em>.Still same paragraph.</p><p>Next <strong>one</strong>.</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "preserves spaces around inline sexp" {
  let input = "Open (span your) eyes."
  let expected = "<p>Open <span>your</span> eyes.</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "converts smart dashes in text" {
  @test.assert_eq(
    render_html_result("a -- b --- c *x -- y --- z*"),
    Ok("<p>a – b — c <em>x – y — z</em></p>"),
  )
}

///|
test "does not convert dashes in raw strings or attributes" {
  @test.assert_eq(
    render_html_result("(span (:data `a---b--c`) `x---y--z`)"),
    Ok("<p><span data=\"a---b--c\">x---y--z</span></p>"),
  )
}

///|
test "def references and interpolated attributes" {
  let input = "(let lang `zh`)(let base `/docs`)(p (:class \"doc-(lang)\") (a (:href \"(base)/intro\") \"语言：(lang)\"))"
  let expected = "<p class=\"doc-zh\"><a href=\"/docs/intro\">语言：zh</a></p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "unknown zero arg sexp is empty tag but bound name expands" {
  let input = "(let x (em yes))(p (x)(em))"
  let expected = "<p><em>yes</em><em></em></p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "section title and local condition" {
  let input = "(section (:title \"Intro\") (let draft true)(when (draft) (note draft)))"
  let expected = "<section><h1>Intro</h1><aside class=\"note\">draft</aside></section>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "mixed block keeps simple nested text unwrapped" {
  let input =
    #|(block
    #|Nested line one
    #|Nested line two)
  let expected = "<div>Nested line oneNested line two</div>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "block children preserve explicit structure" {
  let input =
    #|(block
    #|First paragraph.
    #|
    #|Second paragraph.
    #|(p Explicit paragraph.))
  let expected = "<div>First paragraph.\n\nSecond paragraph.<p>Explicit paragraph.</p></div>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "h-prefixed unknown tag remains inline" {
  @test.assert_eq(
    render_html_result("Before (happy ok) after."),
    Ok("<p>Before <happy>ok</happy> after.</p>"),
  )
}

///|
test "custom structural elements preserve explicit structure" {
  let input =
    #|(x-card
    #|First paragraph.
    #|
    #|Second paragraph.)
  let expected = "<x-card>First paragraph.\n\nSecond paragraph.</x-card>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "flow containers are not wrapped in paragraphs" {
  @test.assert_eq(
    render_html_result("(header Site)Body"),
    Ok("<header>Site</header><p>Body</p>"),
  )
  @test.assert_eq(
    render_html_result("(nav (a (:href `/`) Home))Body"),
    Ok("<nav><a href=\"/\">Home</a></nav><p>Body</p>"),
  )
}

///|
test "block children do not infer paragraphs through local refs" {
  let input =
    #|(block
    #|  (let body `First.
    #|
    #|Second.`)
    #|  (body))
  let expected = "<div>First.\n\nSecond.</div>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "template supports positional and named arguments" {
  let input =
    #|(def reorder (x y z) (p (z) (y) (x)))
    #|(reorder (:y `Y`) `X` `Z`)
  let expected = "<p>Z Y X</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "template supports fragments and attributes" {
  let input =
    #|(def badge (kind body)
    #|  (span (:class "badge badge-(kind)") (body)))
    #|(badge (:kind `info`) (em Careful))
  let expected = "<p><span class=\"badge badge-info\"><em>Careful</em></span></p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "underscore groups multiple values as one template argument" {
  let input =
    #|(def joined (body) (p (body)))
    #|(joined (_ "a" "b" "c"))
  let expected = "<p>a b c</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "underscore does not render a wrapper tag" {
  @test.assert_eq(render_html_result("(_ (em a) b)"), Ok("<p><em>a</em> b</p>"))
}

///|
test "template definitions are hoisted within the same scope" {
  let input =
    #|(card Hello)
    #|(def card (body) (p (body)))
  @test.assert_eq(render_html_result(input), Ok("<p>Hello</p>"))
}

///|
test "compile fragment accepts injected env from collected bindings" {
  let component = parse_doc("(def badge (body) (span (:class `badge`) (body)))")
  let env = collect_env(component)
  let doc = parse_doc("(badge Hello)")
  @test.assert_eq(
    render_fragment_result(doc, env~),
    Ok("<p><span class=\"badge\">Hello</span></p>"),
  )
}

///|
test "collected template captures definition env" {
  let component = parse_doc(
    "(let tone `module`)(def badge () (span (:class \"tone-(tone)\") ok))",
  )
  let env = collect_env(component)
  let doc = parse_doc("(let tone `local`)(badge)")
  @test.assert_eq(
    render_fragment_result(doc, env~),
    Ok("<p><span class=\"tone-module\">ok</span></p>"),
  )
}

///|
test "collect bindings exports doc values for conditions" {
  let module_doc = parse_doc("(doc (:draft true))")
  let env = collect_env(module_doc)
  let doc = parse_doc("(when (draft) Visible)")
  @test.assert_eq(render_fragment_result(doc, env~), Ok("<p>Visible</p>"))
}

///|
test "template hoisting does not cross child scopes" {
  let input =
    #|(section (:title "Outer")
    #|  (section (:title "Inner")
    #|    (def card (body) (p (body))))
    #|  (card Hello))
  let expected = "<section><h1>Outer</h1><section><h2>Inner</h2></section><card>Hello</card></section>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "template reports argument errors" {
  let unknown_arg =
    #|template error at line 1, column 20: unknown template argument: missing
    #|1 | (def t (x) (x))(t (:missing nope))
    #|  |                    ^
  let too_many_args =
    #|template error at line 1, column 28: too many template arguments
    #|1 | (def t (x) (x))(t (:x one) two)
    #|  |                            ^
  let duplicate_arg =
    #|template error at line 1, column 27: duplicate template argument: x
    #|1 | (def t (x) (x))(t (:x one :x two))
    #|  |                           ^
  let missing_arg =
    #|template error at line 1, column 19: missing template argument: y
    #|1 | (def t (x y) (x))(t one)
    #|  |                   ^
  let missing_arg_text_run =
    #|template error at line 1, column 19: missing template argument: y
    #|1 | (def t (x y) (x))(t one two)
    #|  |                   ^
  @test.assert_eq(
    render_html_result("(def t (x) (x))(t (:missing nope))"),
    Err(unknown_arg),
  )
  @test.assert_eq(
    render_html_result("(def t (x) (x))(t (:x one) two)"),
    Err(too_many_args),
  )
  @test.assert_eq(
    render_html_result("(def t (x) (x))(t (:x one :x two))"),
    Err(duplicate_arg),
  )
  @test.assert_eq(
    render_html_result("(def t (x y) (x))(t one)"),
    Err(missing_arg),
  )
  @test.assert_eq(
    render_html_result("(def t (x y) (x))(t one two)"),
    Err(missing_arg_text_run),
  )
}

///|
test "syntax errors include source location" {
  let expected =
    #|syntax error at line 2, column 1: unexpected ')'
    #|2 | )
    #|  | ^
  @test.assert_eq(render_html_result("first\n)"), Err(expected))
}

///|
test "syntax errors include source id when provided" {
  let expected =
    #|syntax error at docs/intro.tm:2:1: unexpected ')'
    #|2 | )
    #|  | ^
  let info : @core.SourceInfo = {
    id: Some("docs/intro.tm"),
    line_offset: 0,
    column_offset: 0,
  }
  match @core.parse("first\n)", source_info=info) {
    Ok(_) => abort("expected parse error")
    Err(diagnostic) => @test.assert_eq(diagnostic.render(), expected)
  }
}

///|
test "list item syntax errors keep original location" {
  let expected =
    #|syntax error at line 2, column 3: unexpected ')'
    #|2 | )
    #|  | ^
  @test.assert_eq(render_html_result("- ok\n- )"), Err(expected))
}

///|
test "compile errors include source location" {
  let input =
    #|(let label (em hot))
    #|(span (:class (label)) Sale)
  let expected =
    #|type error at line 1, column 12: expected scalar value, but got rich content
    #|1 | (let label (em hot))
    #|  |            ^
  @test.assert_eq(render_html_result(input), Err(expected))
}

///|
test "plain text errors include source location" {
  let expected =
    #|content model error at line 1, column 13: expected plain text content
    #|1 | (codeblock (em js))
    #|  |             ^
  @test.assert_eq(render_html_result("(codeblock (em js))"), Err(expected))
}

///|
test "structural nesting does not wrap table cells in paragraphs" {
  let input = "(table (tbody (tr (td A) (td B))))"
  let expected = "<table><tbody><tr><td>A</td> <td>B</td></tr></tbody></table>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "html code tag remains inline" {
  let input = "Use (code cargo test)."
  let expected = "<p>Use <code>cargo test</code>.</p>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "list sugar and block quote codeblock" {
  let input =
    #|- one
    #|- two
    #|
    #|(codeblock (:lang `js`))
    #|```
    #|console.log(1)
    #|```
  let expected = "<ul><li>one</li><li>two</li></ul><pre><code class=\"lang-js\">console.log(1)\n</code></pre>"
  @test.assert_eq(render_html_result(input), Ok(expected))
}

///|
test "dash tag aliases item" {
  let input = "(list (- one) (- two))"
  let expected = "<ul><li>one</li> <li>two</li></ul>"
  @test.assert_eq(render_html_result(input), Ok(expected))
  @test.assert_eq(
    render_html_result(input),
    render_html_result("(list (item one) (item two))"),
  )
}

///|
test "html scoped style supports pseudo classes" {
  let input =
    #|(html.head
    #|  (style (:scope `article`)
    #|    (& (:max-width `68ch`))
    #|    (&:hover (:color `red`))
    #|    (a:hover (:text-decoration `underline`))
    #|    (.lead::first-line (:font-weight `700`))
    #|    (h1 (:margin `0`))
    #|    (h2:focus-within (:color `blue`))))
    #|(block (:class `article`) Body)
  let expected =
    #|<html>
    #|  <head>
    #|    <style>.article{max-width:68ch;}.article:hover{color:red;}.article a:hover{text-decoration:underline;}.article .lead::first-line{font-weight:700;}.article h1{margin:0;}.article h2:focus-within{color:blue;}</style>
    #|  </head>
    #|  <body>
    #|    <div><div class="article">Body</div></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options=HtmlDocumentOptions::empty()),
    Ok(expected),
  )
}

///|
test "html style without scope remains global" {
  let input =
    #|(html.head
    #|  (style
    #|    (body (:margin `0`))
    #|    (a:hover (:color `red`))))
    #|Body
  let expected =
    #|<html>
    #|  <head>
    #|    <style>body{margin:0;}a:hover{color:red;}</style>
    #|  </head>
    #|  <body>
    #|    <div><p>Body</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options=HtmlDocumentOptions::empty()),
    Ok(expected),
  )
}

///|
test "html document uses altsia doc and explicit html head" {
  let input =
    #|(doc 
    #|  ( :title "Doc" 
    #|    :lang `zh-CN` 
    #|    :dir `ltr` 
    #|    :description "Desc" 
    #|    :author "Ada"))
    #|(html.head
    #|  (link (:rel `stylesheet` :href `/style.css`))
    #|  (script (:type `module` :src `/main.js`)))
    #|
    #|Hello (title).
  let expected =
    #|<html lang="zh-CN" dir="ltr">
    #|  <head>
    #|    <title>Doc</title>
    #|    <meta name="description" content="Desc">
    #|    <meta name="author" content="Ada">
    #|    <link rel="stylesheet" href="/style.css">
    #|    <script type="module" src="/main.js"></script>
    #|  </head>
    #|  <body>
    #|    <div><p>Hello Doc.</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options=HtmlDocumentOptions::empty()),
    Ok(expected),
  )
}

///|
test "html document uses backend defaults" {
  let input = "(doc (:title \"Doc\"))Body"
  let expected =
    #|<!DOCTYPE html>
    #|<html>
    #|  <head>
    #|    <meta charset="utf-8">
    #|    <meta name="viewport" content="width=device-width, initial-scale=1">
    #|    <title>Doc</title>
    #|  </head>
    #|  <body>
    #|    <div><p>Body</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options={
      initial_heading_level: 1,
      wrap_inline_content: true,
      extensions: [],
      doctype: Some("html"),
      charset: Some("utf-8"),
      viewport: Some("width=device-width, initial-scale=1"),
      extra_head: [],
    }),
    Ok(expected),
  )
}

///|
test "html doc overrides backend defaults" {
  let input = "(doc (:charset `shift_jis` :viewport `custom`))Body"
  let expected =
    #|<!DOCTYPE html>
    #|<html>
    #|  <head>
    #|    <meta charset="shift_jis">
    #|    <meta name="viewport" content="custom">
    #|  </head>
    #|  <body>
    #|    <div><p>Body</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options={
      initial_heading_level: 1,
      wrap_inline_content: true,
      extensions: [],
      doctype: Some("html"),
      charset: Some("utf-8"),
      viewport: Some("width=device-width, initial-scale=1"),
      extra_head: [],
    }),
    Ok(expected),
  )
}

///|
test "html doc attrs apply to body wrapper" {
  let input = "(doc (:title \"Doc\" :class `page` :style `--gap: 1rem`))Body"
  let expected =
    #|<html>
    #|  <head>
    #|    <title>Doc</title>
    #|  </head>
    #|  <body>
    #|    <div class="page" style="--gap: 1rem"><p>Body</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result(input, options=HtmlDocumentOptions::empty()),
    Ok(expected),
  )
}

///|
test "html doc paper appends to final body class" {
  let input = "(doc (:class \"page hero\" :data-x `1` :class `wide` :paper `a4`))Body"
  @test.assert_eq(
    render_html_document_result(input, options=HtmlDocumentOptions::empty()).map(html => {
        html.contains(
          "<div class=\"wide paper\" data-x=\"1\"><p>Body</p></div>",
        ) &&
        !html.contains("page hero")
      },
    ),
    Ok(true),
  )
}

///|
test "html doc paper rejects unknown preset" {
  match
    render_html_document_result(
      "(doc (:paper `letter`))Body",
      options=HtmlDocumentOptions::empty(),
    ) {
    Err(message) =>
      @test.assert_eq(message.contains("unknown paper slate: letter"), true)
    Ok(_) => abort("expected paper preset error")
  }
}

///|
test "html document appends extra head after defaults" {
  let input = "(doc (:title \"Math\"))$x$"
  @test.assert_eq(
    render_html_document_result(input, options={
      initial_heading_level: 1,
      wrap_inline_content: true,
      extensions: [],
      doctype: Some("html"),
      charset: Some("utf-8"),
      viewport: Some("width=device-width, initial-scale=1"),
      extra_head: [
        @sexp.SexpNode::RawHtml("<script src=\"/math.js\"></script>"),
      ],
    }).map(html => html.contains("<script src=\"/math.js\"></script>")),
    Ok(true),
  )
}

///|
test "extension resolver handles element and fallback preserves html" {
  let resolver : ElementResolver = compiler => {
    if compiler.call.tag == "icon" {
      Ok(
        Some(
          ElementOutput::body([
            @sexp.SexpNode::Element(
              "span",
              @sexp.HtmlAttrs({ "class": Some("icon") }),
              [@sexp.SexpNode::Text("search")],
            ),
          ]),
        ),
      )
    } else {
      Ok(None)
    }
  }
  let options : CompileOptions = {
    initial_heading_level: 1,
    wrap_inline_content: true,
    extensions: [resolver],
  }
  @test.assert_eq(
    render_fragment_result(parse_doc("(icon search)(custom ok)"), options~),
    Ok("<p><span class=\"icon\">search</span><custom>ok</custom></p>"),
  )
}

///|
test "extension resolver can emit document head nodes" {
  let resolver : ElementResolver = compiler => {
    if compiler.call.tag == "asset" {
      return Ok(
        Some(
          ElementOutput::head([
            @sexp.SexpNode::RawHtml("<script src=\"/asset.js\"></script>"),
          ]),
        ),
      )
    }
    Ok(None)
  }
  let doc_options = { ..HtmlDocumentOptions::empty(), extensions: [resolver] }
  let expected =
    #|<html>
    #|  <head>
    #|    <script src="/asset.js"></script>
    #|  </head>
    #|  <body>
    #|    <div><p>Body</p></div>
    #|  </body>
    #|</html>
  @test.assert_eq(
    render_html_document_result("(asset)Body", options=doc_options),
    Ok(expected),
  )
  let fragment_options = {
    ..CompileOptions::fragment(),
    extensions: [resolver],
  }
  @test.assert_eq(
    render_fragment_result(parse_doc("(asset)Body"), options=fragment_options),
    Ok("<p>Body</p>"),
  )
}

///|
test "extension resolver diagnostic keeps source span" {
  let resolver : ElementResolver = compiler => {
    if compiler.call.tag == "boom" {
      Err(
        compiler.call.span.diagnostic(
          @core.DiagnosticPhase::ContentModel,
          "boom",
        ),
      )
    } else {
      Ok(None)
    }
  }
  let options : CompileOptions = {
    initial_heading_level: 1,
    wrap_inline_content: true,
    extensions: [resolver],
  }
  let expected =
    #|content model error at line 1, column 2: boom
    #|1 | (boom now)
    #|  |  ^
  @test.assert_eq(
    render_fragment_result(parse_doc("(boom now)"), options~),
    Err(expected),
  )
}

///|
test "html head is ignored by fragment output" {
  let input = "(html.head (title Hidden))Visible"
  @test.assert_eq(render_html_result(input), Ok("<p>Visible</p>"))
}
