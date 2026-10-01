///|
pub const HTML_KATEX_RENDER : String =
  #|<!-- Also see: https://katex.org/docs/autorender -->
  #|<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.18.5/dist/katex.min.css" integrity="sha384-2dNi/m6JtSiviznrOIZ5fTiZ5As0In2QwkuXSgoqcQtCNplvJAbt+jveeN+8en73" crossorigin="anonymous">
  #|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.18.5/dist/katex.min.js" integrity="sha384-TTF8eEsEKInX2meLzP5V1z/npGYIElXYGksx93f0qBZHu6IL3PdzVB8objytx+TR" crossorigin="anonymous"></script>
  #|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.18.5/dist/contrib/auto-render.min.js" integrity="sha384-bjyGPfbij8/NDKJhSGZNP/khQVgtHUE5exjm4Ydllo42FwIgYsdLO2lXGmRBf5Mz" crossorigin="anonymous"></script>
  #|<!-- Also see: https://github.com/KaTeX/KaTeX/tree/main/contrib/copy-tex -->
  #|<script src="https://cdn.jsdelivr.net/npm/katex@0.18.5/dist/contrib/copy-tex.min.js" integrity="sha384-Pe2JWbaShhSRT0SESJ9XLPeAsi4yrNi7r/CiH0Coq7giBjK5a6Ae7XcybE8rNlQP" crossorigin="anonymous"></script>
  #|
  #|<script>
  #|  document.addEventListener("DOMContentLoaded", function () {
  #|    renderMathInElement(document.body, {
  #|      delimiters: [
  #|        { left: "$$", right: "$$", display: true },
  #|        { left: "$", right: "$", display: false },
  #|        { left: "\\(", right: "\\)", display: false },
  #|        { left: "\\[", right: "\\]", display: true },
  #|      ],
  #|      trust: true,
  #|      strict: false,
  #|      throwOnError: false,
  #|      minRuleThickness: 0.05,
  #|    });
  #|  });
  #|</script>

///|
pub const HTML_KATEX_FONT_RESIZE : String =
  $|<style>
  $|:root body {
  $|  --text-font-family: \{TEXT_FONT_SERIF};
  $|  --katex-font-size: 1em;
  $|  --katex-frac-line-font-size: 1.25em;
  $|}
  $|
  $|.katex {
  $|  font: normal var(--katex-font-size) KaTeX_Main, Times New Roman, serif;
  $|  line-height: 1rem;
  $|  text-indent: 0;
  $|  text-rendering: auto;
  $|}
  $|
  $|.katex .mfrac .frac-line {
  $|  font-size: var(--katex-frac-line-font-size);
  $|}
  $|
  $|.katex-display {
  $|  overflow-x: auto;
  $|  overflow-y: hidden;
  $|}
  $|
  $|.cjk_fallback {
  $|  font-size: 1em;
  $|  font-family: var(--text-font-family);
  $|}
  $|
  $|.katex-display .katex {
  $|  /* Inconsistent bounding box at different font sizes. */
  $|  /* Also see: https://github.com/KaTeX/KaTeX/issues/3965 */
  $|  padding-top: 1px;
  $|}
  $|
  $|p:has(span.katex-html:empty) {
  $|  display: none;
  $|}
  $|</style>
