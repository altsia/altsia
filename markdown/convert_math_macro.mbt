///|
fn is_katex_macro_definition(tex : String) -> Bool {
  let macro_prefixes = [
    "\\def\\", "\\gdef\\", "\\edef\\", "\\xdef\\", "\\let\\", "\\newcommand", "\\renewcommand",
    "\\providecommand",
  ]
  macro_prefixes.iter().any(prefix => tex.has_prefix(prefix))
}

///|
fn should_convert_katex_to_app(tex : String, mode : KatexConvertMode) -> Bool {
  // Macro definitions must be emitted as app-form eagerly.
  // If kept as $...$ text, the macros are only executed in text-visitor stage,
  // so app-form formulas cannot share those macro definitions.
  if is_katex_macro_definition(tex) {
    return true
  }
  match mode {
    AlwaysApp => true
    NeverApp => false
    AppWhenHasParens => tex.contains("(") || tex.contains(")")
  }
}
