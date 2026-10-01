///|
/// HTML-extension nodes (`\htmlClass`/`\htmlId`/`\htmlStyle`/`\htmlData`) and
/// trusted `\includegraphics`/`\href` nodes appear only under a trusted
/// policy; they must round-trip idempotently like everything else.
test "canonical trusted html and graphics re-parse idempotently" {
  let settings = @katex.Settings::make(trust=@katex.TrustPolicy::Trusted)
  let inputs = [
    "\\htmlClass{my-class}{x}", "\\htmlId{my-id}{x}", "\\htmlStyle{color:red}{x}",
    "\\htmlData{a=b}{x}", "\\includegraphics[width=1em,height=2em]{img.png}", "\\href{https://example.com}{link}",
  ]
  for tex in inputs {
    let once = @canonical.render(@katex.parse(tex, settings~))
    let twice = @canonical.render(@katex.parse(once, settings~))
    @test.assert_eq(twice, once, msg="trusted round-trip: \{tex} -> \{once}")
  }
}
