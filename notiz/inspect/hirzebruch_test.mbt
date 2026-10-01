///|
test {
  let content =
    #|
    #|$$
    #|\def\thm{\@ifnextchar[{\thm@with}{\thm@without}}
    #|\def\thm@with[#1]{\textbf{Theorem~(#1).}}
    #|\def\thm@without{\textbf{Theorem.}}
    #|$$
    #|
    #|$\thm[Hirzebruch--Riemann--Roch]$ Let $X$ be a complete nonsingular variety. For
    #|$$\chi(X, E) ~=~ \int_X \operatorname{ch}(E) \cdot \operatorname{td}(T_X)$$
    #|
    #|where $\operatorname{ch}(-)$ denotes the Chern character and $\operatorname{td}(-)$ the Todd class.
    #|

  let expected =
    #|Theorem (Hirzebruch–Riemann–Roch). Let X be a complete nonsingular variety. For
    #|
    #|χ(X, E) = ∫_X ch(E) ⋅ td(T_X)
    #|
    #|where ch(−) denotes the Chern character and td(−) the Todd class.

  let actual = @parsing.document.parse(@talc.Input::new(content))
    |> Result::unwrap
    |> @backend.render_terminal_document
  @test.assert_eq(actual, expected)
}
