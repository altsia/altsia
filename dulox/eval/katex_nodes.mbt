///|
let emptyset : @katex.ParseNode = TextOrd(
  mode=Math,
  loc=None,
  text="\\varnothing",
)

///|
let space : @katex.ParseNode = Spacing(mode=Math, loc=None, text="\\space")

///|
let comma : @katex.ParseNode = Atom(
  mode=Math,
  loc=None,
  family=Mpunct,
  text=",",
)

///|
let plus : @katex.ParseNode = Atom(mode=Math, loc=None, family=Mbin, text="+")

///|
let minus : @katex.ParseNode = Atom(mode=Math, loc=None, family=Mbin, text="-")

///|
let reals : @katex.ParseNode = Font(
  mode=Math,
  font="mathbb",
  body=MathOrd(mode=Math, loc=None, text="R"),
)

///|
let complex_numbers : @katex.ParseNode = Font(
  mode=Math,
  font="mathbb",
  body=MathOrd(mode=Math, loc=None, text="C"),
)

///|
let image_unit : @katex.ParseNode = MathOrd(mode=Math, loc=None, text="i")

///|
let unknown : @katex.ParseNode = Raw(mode=Math, string="?")
