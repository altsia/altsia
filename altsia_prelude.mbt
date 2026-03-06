///|
pub let altsia_prelude : String = template_anonymous_subtree +
  [
    "exegesis", "definition", "proposition", "remark", "conjecture", "postulate",
    "claim", "observation", "fact", "hypothesis", "axiom", "lemma", "theorem", "corollary",
    "example", "proof",
  ]
  .map(builtin_anonymous_subtree)
  .join("\n")

///|
let template_anonymous_subtree : String =
  #|
  #|(λ inline-section (taxon (title) content...)
  #|  (section (:class inline block) (:data-taxon)
  #|    (details (:open)
  #|      (summary (header (h1 (span (:class taxon) (taxon).) (~) (title)))) (content) ) ) )
  #|
  #|(λ block ((:title ()) (:taxon) content...)
  #|  (inline-section (:taxon) (:title) (content)) )

///|
fn builtin_anonymous_subtree(taxon : String) -> String {
  let taxon_display = @kodama.Taxon::text_transform(taxon)
  (
    $|(λ \{taxon} ((:title ()) content...)
    $|  (inline-section (_ \{taxon_display}) (:title) (content)) )
  )
}
