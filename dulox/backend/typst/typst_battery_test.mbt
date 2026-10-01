///|
/// A battery case: the input `tex`, the expected Typst source, and a name
/// used in assertion messages.
struct BatteryCase {
  name : String
  tex : String
  expected : String
}

///|
/// Battery of representative equations locking in the Typst backend output.
/// Each case renders `tex` with the parser and compares against the expected
/// Typst source; regenerate after intentional emission changes.
let battery_cases : Array[BatteryCase] = [
  {
    name: "sum_limits",
    tex: "\\sum_{i=0}^{n} i^2",
    expected: "∑^n_(i = 0) i^2",
  },
  { name: "frac", tex: "\\frac{a+1}{b-2}", expected: "(a + 1) / (b − 2)", },
  { name: "dfrac", tex: "\\dfrac{x}{y}", expected: "display(x / y)", },
  { name: "tfrac", tex: "\\tfrac{1}{2}", expected: "inline(1 / 2)", },
  { name: "binom", tex: "\\binom{n}{k}", expected: "binom(n, k)", },
  { name: "sqrt", tex: "\\sqrt{x^2+y^2}", expected: "sqrt(x^2 + y^2)", },
  { name: "root", tex: "\\sqrt[3]{x}", expected: "root(3, x)", },
  { name: "sup_sub", tex: "x_i^2 + a_b^c", expected: "x^2_i + a^c_b", },
  {
    name: "prime",
    tex: "x' + y'' + z'''",
    expected: "x^′ + y^′′ + z^′′′",
  },
  {
    name: "left_right",
    tex: "\\left(\\frac{a}{b}\\right)",
    expected: "lr(\\( a / b \\))",
  },
  {
    name: "left_right_big",
    tex: "\\left\\{ x \\middle| x \\in \\mathbb{R} \\right\\}",
    expected: "lr(\\{ x mid(∣) x ∈ bb(R) \\})",
  },
  {
    name: "left_dot",
    tex: "\\left. \\frac{a}{b} \\right|",
    expected: "a / b lr(size: #2em, ∣)",
  },
  {
    name: "big",
    tex: "\\big( a \\big) + \\Big[ b \\Big] + \\bigg\\{ c \\bigg\\}",
    expected: "lr(size: #1.2em, \\() a lr(size: #1.2em, \\)) + lr(size: #1.8em, \\[) b lr(size: #1.8em, \\]) + lr(size: #2.4em, \\{) c lr(size: #2.4em, \\})",
  },
  {
    name: "matrix",
    tex: "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
    expected: "mat(a, b; c, d, delim: \"(\")",
  },
  {
    name: "bmatrix",
    tex: "\\begin{bmatrix} 1 & 2 \\\\ 3 & 4 \\end{bmatrix}",
    expected: "mat(1, 2; 3, 4, delim: \"[\")",
  },
  {
    name: "vmatrix",
    tex: "\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}",
    expected: "mat(a, b; c, d, delim: \"|\")",
  },
  {
    name: "cases",
    tex: "f(x) = \\begin{cases} x^2 & x > 0 \\\\ 0 & x = 0 \\\\ -x & x < 0 \\end{cases}",
    expected: "f(x) = cases(x^2 & x > 0, 0 & x = 0, − x & x < 0)",
  },
  {
    name: "aligned",
    tex: "\\begin{aligned} x &= y + z \\\\ &= 2 \\end{aligned}",
    expected: "display(x) & display(= y + z) \\  & display(= 2)",
  },
  {
    name: "array_hlines",
    tex: "\\begin{array}{c|cc} a & b & c \\\\ \\hline d & e & f \\end{array}",
    expected: "#table(\n  columns: 3,\n  align: center,\n  stroke: none,\n  [$a$], table.vline(), [$b$], [$c$],\n  table.hline(),\n  [$d$], [$e$], [$f$],\n)",
  },
  {
    name: "array_dash",
    tex: "\\begin{array}{c|c} a & b \\\\ \\hdashline c & d \\end{array}",
    expected: "#table(\n  columns: 2,\n  align: center,\n  stroke: none,\n  [$a$], table.vline(), [$b$],\n  table.hline(stroke: (thickness: 0.5pt, dash: (2pt, 1pt))),\n  [$c$], [$d$],\n)",
  },
  {
    name: "substack",
    tex: "\\sum_{\\substack{i=0 \\\\ j=0}}^{n} x",
    expected: "∑^n_mat(script(i = 0); script(j = 0)) x",
  },
  {
    name: "hat",
    tex: "\\hat{x} + \\widehat{abc}",
    expected: "hat(x) + hat(a b c)",
  },
  {
    name: "accents",
    tex: "\\vec{v} + \\dot{a} + \\ddot{b} + \\bar{c} + \\tilde{d} + \\tilde{def}",
    expected: "arrow(v) + dot(a) + dot.double(b) + macron(c) + tilde(d) + tilde(d e f)",
  },
  {
    name: "arrow_accents",
    tex: "\\overrightarrow{AB} + \\overleftarrow{CD} + \\vec{x}",
    expected: "arrow(A B) + arrow.l(C D) + arrow(x)",
  },
  {
    name: "overbrace",
    tex: "\\overbrace{a+b+c}^{n} + \\underbrace{x+y}_{m}",
    expected: "attach(overbrace(a + b + c), t: n) + attach(underbrace(x + y), b: m)",
  },
  {
    name: "xrightarrow",
    tex: "\\xrightarrow{f} x \\xrightarrow[below]{above} y",
    expected: "attach(arrow.r, t: f) x attach(arrow.r, t: a b o v e, b: b e l o w) y",
  },
  {
    name: "xleftrightarrow",
    tex: "a \\xleftrightarrow{g} b",
    expected: "a attach(arrow.l.r, t: g) b",
  },
  {
    name: "not",
    tex: "\\not= \\quad \\not\\in \\quad \\not<",
    expected: "cancel(=) #h(1em) cancel(∈) #h(1em) cancel(<)",
  },
  {
    name: "pmod",
    tex: "x \\equiv y \\pmod{n} \\quad a \\bmod b",
    expected: "x ≡ y #h(0.444em) (mod #h(0.333em) n) #h(1em) a #h(0.056em) mod #h(0.056em) b",
  },
  {
    name: "overset",
    tex: "\\overset{*}{f} \\quad \\underset{x \\to 0}{\\lim}",
    expected: "limits(op(f))^∗ #h(1em) limits(op(lim))_(x → 0)",
  },
  {
    name: "operatorname",
    tex: "\\operatorname{argmax}_{x} f(x) \\quad \\operatorname*{res}_{x=0}",
    expected: "op(\"argmax\")_x f(x) #h(1em) op(\"res\")_(x = 0)",
  },
  {
    name: "text",
    tex: "\\text{hello world} \\quad \\text{if } x > 0 \\text{ then}",
    expected: "text\"hello\u{a0}world\" #h(1em) text\"if\u{a0}\" x > 0 text\"\u{a0}then\"",
  },
  {
    name: "textbf",
    tex: "\\textbf{bold} \\quad \\textit{italic} \\quad \\texttt{mono}",
    expected: "#strong[$text\"bold\"$] #h(1em) #emph[$text\"italic\"$] #h(1em) text\"mono\"",
  },
  {
    name: "fonts",
    tex: "\\mathbb{R} \\mathbf{v} \\mathcal{L} \\mathfrak{g} \\mathsf{S} \\mathtt{t}",
    expected: "bb(R) bold(v) cal(L) frak(g) sans(S) mono(t)",
  },
  {
    name: "color",
    tex: "\\textcolor{red}{x} + \\color{blue}{y}",
    expected: "text(fill: #rgb(\"#ff0000\"), x) + text(fill: #rgb(\"#0000ff\"), y)",
  },
  {
    name: "boxed",
    tex: "\\boxed{x^2} \\quad \\fcolorbox{red}{yellow}{x}",
    expected: "#box(stroke: 0.5pt, $display(x^2)$) #h(1em) #box(stroke: 0.5pt + rgb(\"#ff0000\"), fill: rgb(\"#ffff00\"), $x$)",
  },
  {
    name: "rule",
    tex: "x \\rule{2em}{0.5pt} y",
    expected: "x #rect(width: 2em, height: 0.5pt) y",
  },
  {
    name: "raisebox",
    tex: "x \\raisebox{0.5ex}{y} z",
    expected: "x #place(dy: 0.25em, $y$) z",
  },
  {
    name: "kern",
    tex: "a \\kern0.5em b \\quad a \\! b",
    expected: "a #h(0.5em) b #h(1em) a #h(-0.167em) b",
  },
  {
    name: "spacing",
    tex: "a \\; b \\quad a \\: b \\quad a \\, b",
    expected: "a #h(0.278em) b #h(1em) a #h(0.222em) b #h(1em) a #h(0.167em) b",
  },
  {
    name: "dddot",
    tex: "\\dddot{x} \\quad \\ddddot{y}",
    expected: "accent(x, dot.triple) #h(1em) accent(y, dot.quad)",
  },
  { name: "mathring", tex: "\\mathring{A}", expected: "circle(A)", },
  {
    name: "genfrac",
    tex: "\\genfrac{}{}{0pt}{}{a}{b} \\quad \\genfrac{(}{)}{0pt}{}{n}{k}",
    expected: "a / b #h(1em) binom(n, k)",
  },
  {
    name: "sizing",
    tex: "{\\small x} + {\\large y}",
    expected: "text(size: #0.9em, x) + text(size: #1.2em, y)",
  },
  { name: "hspace", tex: "a \\hspace{1em} b", expected: "a #h(1em) b", },
  {
    name: "phantom",
    tex: "a\\phantom{b}c",
    expected: "a #box(height: 0.5em) c",
  },
  { name: "smash", tex: "\\smash{x}", expected: "x", },
  { name: "notsubset", tex: "\\not\\subset A", expected: "cancel(⊂) A", },
  {
    name: "lim_op",
    tex: "\\lim_{x \\to 0} \\frac{\\sin x}{x}",
    expected: "lim_(x → 0) (sin x) / x",
  },
  {
    name: "coloneqq",
    tex: "a \\coloneqq b \\quad c := d",
    expected: "a op(≔) b #h(1em) c : = d",
  },
  {
    name: "verts",
    tex: "\\Vert x \\Vert \\quad \\lVert x \\rVert",
    expected: "norm(x) #h(1em) norm(x)",
  },
  {
    name: "angles",
    tex: "\\langle x \\rangle \\quad \\lfloor y \\rfloor \\quad \\lceil z \\rceil",
    expected: "⟨ x ⟩ #h(1em) ⌊ y ⌋ #h(1em) ⌈ z ⌉",
  },
  {
    name: "dots",
    tex: "a + \\cdots + z \\quad x_1, \\ldots, x_n",
    expected: "a + ⋯ + z #h(1em) x_1 , … , x_n",
  },
  {
    name: "arrows",
    tex: "\\to \\leftarrow \\Rightarrow \\Leftrightarrow \\mapsto",
    expected: "→ ← ⇒ ⇔ ↦",
  },
  {
    name: "operators",
    tex: "\\sin x \\quad \\log_2 n \\quad \\lim_{n \\to \\infty} \\frac{1}{n}",
    expected: "sin x #h(1em) log_2 n #h(1em) lim_(n → ∞) 1 / n",
  },
  {
    name: "frac_nested",
    tex: "\\frac{\\frac{a}{b}}{\\frac{c}{d}}",
    expected: "(a / b) / (c / d)",
  },
  {
    name: "overline_underline",
    tex: "\\overline{xy} + \\underline{ab}",
    expected: "overline(x y) + underline(a b)",
  },
  {
    name: "html_mathml",
    tex: "\\notin \\quad \\neq \\quad \\le \\quad \\ge",
    expected: "∉ #h(1em) ≠ #h(1em) ≤ #h(1em) ≥",
  },
  { name: "pmb", tex: "\\pmb{\\alpha}", expected: "α", },
  { name: "mathchoice", tex: "\\sum_{i=1}^{n} i", expected: "∑^n_(i = 1) i", },
  {
    name: "scriptstyle",
    tex: "\\scriptstyle x \\quad \\scriptscriptstyle y",
    expected: "script(x #h(1em) sscript(y))",
  },
  { name: "sqrt_nested", tex: "\\sqrt{\\sqrt{x}}", expected: "sqrt(sqrt(x))", },
  {
    name: "text_complex",
    tex: "\\text{a very long text with spaces and } x^2",
    expected: "text\"a\u{a0}very\u{a0}long\u{a0}text\u{a0}with\u{a0}spaces\u{a0}and\u{a0}\" x^2",
  },
]

///|
test "typst battery renders stable output" {
  for case in battery_cases {
    @test.assert_eq(
      @typst.render(@katex.parse(case.tex)),
      case.expected,
      msg=case.name,
    )
  }
}
