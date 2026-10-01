///|
/// A battery case: the input `tex` and its expected canonical output.
struct BatteryCase {
  name : String
  tex : String
  expected : String
}

///|
/// Inputs that must round-trip: re-parsing the canonical output succeeds and
/// rendering it again yields the same string.
let round_trip_inputs : Array[String] = [
  "x", "a+b", "a-b", "x^2", "x_{i}", "x_i^2", "x^{10}", "{x+y}^2", "\\frac{a+1}{b-2}",
  "\\dfrac{x}{y}", "\\tfrac{1}{2}", "\\cfrac{1}{2}", "\\binom{n}{k}", "\\sqrt{x}",
  "\\sqrt[3]{x}", "\\alpha + \\beta", "\\sum_{i=0}^n i^2", "\\int_0^1 x", "\\lim_{x \\to 0} \\frac{\\sin x}{x}",
  "\\sin x + \\cos x", "\\operatorname{rank}(A)", "\\operatorname*{argmax}_x", "x' + y''",
  "\\hat{x} + \\vec{v}", "\\overline{AB}", "\\underline{AB}", "\\left(\\frac{a}{b}\\right)",
  "\\left\\{ x \\middle| x > 0 \\right\\}", "\\left. \\frac{a}{b} \\right|", "\\bigl( a \\bigr) + \\Bigl[ b \\Bigr]",
  "a \\quad b \\qquad c", "a\\,b\\;c\\!d", "\\text{hello world}", "\\textbf{bold} \\textit{italic}",
  "\\mathbb{R}", "\\mathcal{F}", "\\mathbf{x}", "\\mathop{\\mathrm{lim}}", "\\pmb{x}",
  "\\phantom{abc}", "\\smash[b]{x}", "\\overset{a}{b}", "\\underset{a}{b}", "\\stackrel{def}{=}",
  "\\color{red}{x}", "\\textcolor{blue}{y}", "\\cancel{abc}", "\\fbox{abc}", "\\colorbox{red}{x}",
  "\\fcolorbox{red}{blue}{x}", "\\cancel{abc}", "\\underbrace{abc}", "\\xrightarrow{f}",
  "\\xrightarrow[below]{f}", "\\begin{matrix} a & b \\\\ c & d \\end{matrix}", "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
  "\\begin{bmatrix} 1 & 2 \\\\ 3 & 4 \\end{bmatrix}", "\\begin{cases} x & x > 0 \\\\ -x & x \\leq 0 \\end{cases}",
  "\\begin{aligned}a&=b\\\\c&=d\\end{aligned}", "\\begin{array}{c|c} a & b \\\\ \\hline c & d \\end{array}",
  "\\begin{smallmatrix} a & b \\\\ c & d \\end{smallmatrix}", "\\substack{a \\\\ b}",
  "\\genfrac{(}{)}{0pt}{}{a}{b}", "{a \\over b}", "{n \\choose k}", "{a \\atop b}",
  "\\href{https://example.com}{link}", "\\url{https://example.com}", "\\rule{1em}{2pt}",
  "\\raisebox{2pt}{x}", "\\kern{1em}", "\\hspace{2em}", "\\llap{x}", "\\rlap{y}",
  "\\mathchoice{D}{T}{S}{S}", "\\large{x}", "\\tiny{x}", "\\verb|x+y|", "a\\%b",
  "\\#foo", "\\_under", "\\text{\\textbackslash}", "\\allowbreak", "\\underline{AB}",
  "\\vphantom{x}", "\\vcenter{x}", "\\hbox{abc}", "\\underleftarrow{abc}", "\\underrightarrow{abc}",
  "\\overbracket{abc}", "\\underbracket{abc}", "\\left. x \\middle| y \\right.",
  "\\url{https://example.com}", "\\includegraphics[width=1em,height=2em]{img.png}",
  "\\html@mathml{x}{y}", "\\pmb{abc}", "\\mathop{\\mathrm{lim}}", "\\operatorname{lim\\,sup}",
  "\\genfrac{<}{>}{}{}{a}{b}", "{a \\brace b}", "{a \\brack b}", "\\substack{a \\\\ b}",
]

///|
/// Display-mode-only constructs (`\begin{CD}`, `\tag`) round-trip when parsed
/// in display mode.
let display_round_trip_inputs : Array[String] = [
  "\\begin{CD} A @>a>> B \\\\ @VbVV @AAcA \\\\ C @= D \\end{CD}", "x \\tag{*}", "\\tag{1} x",
  "\\begin{equation}x\\end{equation}", "\\begin{align}a&=b\\\\c&=d\\end{align}",
  "\\begin{CD} A @>>b>B \\end{CD}", "\\begin{CD} A @>a>b>B \\end{CD}", "\\begin{CD} A @<a<< B \\end{CD}",
  "\\begin{CD} A @| B \\end{CD}", "\\begin{CD} A @>a>> B @>c>> C \\\\ @VdVV @VeVV @AAfA \\\\ D @= E @= F \\end{CD}",
]

///|
/// The canonical output of every input in `round_trip_inputs` re-parses
/// without error and rendering it again is a fixed point.
test "canonical output re-parses and is idempotent" {
  for tex in round_trip_inputs {
    let once = @canonical.render(@katex.parse(tex))
    let reparse = @katex.parse(once) catch {
      _ => raise Failure("re-parse failed: \{tex} -> \{once}")
    }
    let twice = @canonical.render(reparse)
    @test.assert_eq(twice, once, msg="round-trip: \{tex} -> \{once}")
  }
}

///|
test "canonical display-mode output re-parses and is idempotent" {
  let settings = @katex.Settings::make(display_mode=true)
  for tex in display_round_trip_inputs {
    let once = @canonical.render(@katex.parse(tex, settings~))
    let reparse = @katex.parse(once, settings~) catch {
      _ => raise Failure("re-parse failed: \{tex} -> \{once}")
    }
    let twice = @canonical.render(reparse)
    @test.assert_eq(twice, once, msg="round-trip: \{tex} -> \{once}")
  }
}

///|
test "canonical output expands macros" {
  @test.assert_eq(@canonical.render(@katex.parse("\\def\\foo{x}\\foo")), "x")
  @test.assert_eq(
    @canonical.render(@katex.parse("\\def\\sq#1{#1^2}\\sq{x}")),
    "x^2",
  )
  @test.assert_eq(
    @canonical.render(@katex.parse("\\def\\foo{x}\\foo + \\foo")),
    "x+x",
  )
  @test.assert_eq(@canonical.render(@katex.parse("\\gdef\\bar{y}\\bar")), "y")
  @test.assert_eq(@canonical.render(@katex.parse("\\let\\x=y\\x")), "y")
}

///|
test "canonical battery" {
  for case in battery_cases {
    @test.assert_eq(
      @canonical.render(@katex.parse(case.tex)),
      case.expected,
      msg=case.name,
    )
  }
}

///|
let battery_cases : Array[BatteryCase] = [
  { name: "atom", tex: "x", expected: "x", },
  { name: "plus", tex: "a+b", expected: "a+b", },
  { name: "sup", tex: "x^2", expected: "x^2", },
  { name: "sub", tex: "x_{i}", expected: "x_{i}", },
  { name: "sup_sub", tex: "x_i^2", expected: "x^2_i", },
  { name: "frac", tex: "\\frac{a+1}{b-2}", expected: "\\frac{a+1}{b-2}", },
  { name: "dfrac", tex: "\\dfrac{x}{y}", expected: "\\dfrac{x}{y}", },
  { name: "tfrac", tex: "\\tfrac{1}{2}", expected: "\\tfrac{1}{2}", },
  { name: "binom", tex: "\\binom{n}{k}", expected: "\\binom{n}{k}", },
  { name: "sqrt", tex: "\\sqrt{x}", expected: "\\sqrt{x}", },
  { name: "root", tex: "\\sqrt[3]{x}", expected: "\\sqrt[3]{x}", },
  { name: "sum", tex: "\\sum_{i=0}^n", expected: "\\sum^n_{i=0}", },
  { name: "limit", tex: "\\lim_{x \\to 0}", expected: "\\lim_{x\\to0}", },
  {
    name: "operatorname",
    tex: "\\operatorname{rank}(A)",
    expected: "\\operatorname{rank}(A)",
  },
  {
    name: "operatorname_star",
    tex: "\\operatorname*{argmax}",
    expected: "\\operatorname*{argmax}",
  },
  {
    name: "left_right",
    tex: "\\left(\\frac{a}{b}\\right)",
    expected: "\\left(\\frac{a}{b}\\right)",
  },
  {
    name: "left_right_set",
    tex: "\\left\\{ x \\middle| x > 0 \\right\\}",
    expected: "\\left\\{x\\middle|x>0\\right\\}",
  },
  { name: "text", tex: "\\text{hello world}", expected: "\\text{hello world}", },
  { name: "mathbb", tex: "\\mathbb{R}", expected: "\\mathbb{R}", },
  { name: "overset", tex: "\\overset{a}{b}", expected: "\\overset{a}{b}", },
  { name: "underset", tex: "\\underset{a}{b}", expected: "\\underset{a}{b}", },
  {
    name: "stackrel",
    tex: "\\stackrel{def}{=}",
    expected: "\\stackrel{def}{=}",
  },
  { name: "overbrace", tex: "\\overbrace{abc}", expected: "\\overbrace{abc}", },
  {
    name: "xarrow",
    tex: "\\xrightarrow[below]{f}",
    expected: "\\xrightarrow[below]{f}",
  },
  {
    name: "pmatrix",
    tex: "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
    expected: "\\left(\\begin{array}{cc}\\textstyle{a}&\\textstyle{b}\\\\\\textstyle{c}&\\textstyle{d}\\end{array}\\right)",
  },
  {
    name: "matrix",
    tex: "\\begin{matrix} a & b \\\\ c & d \\end{matrix}",
    expected: "\\begin{array}{cc}\\textstyle{a}&\\textstyle{b}\\\\\\textstyle{c}&\\textstyle{d}\\end{array}",
  },
  {
    name: "cases",
    tex: "\\begin{cases} x & x > 0 \\\\ -x & x \\leq 0 \\end{cases}",
    expected: "\\left\\{\\begin{array}{ll}\\textstyle{x}&\\textstyle{x>0}\\\\\\textstyle{-x}&\\textstyle{x\\leq0}\\end{array}\\right.",
  },
]
