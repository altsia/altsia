///|
pub const MAGIC_SEED_DEFAULT : Int = 5

///|
pub(all) struct BuiltinScheme {
  corpus : String
  delimiter : String
}

///|
pub fn BuiltinScheme::get(name : String) -> BuiltinScheme? {
  match name {
    "lorem" =>
      Some(BuiltinScheme::{ corpus: @ipsum.TEXT_LOREM, delimiter: "en" })
    "cras" =>
      Some(BuiltinScheme::{
        corpus: @ipsum.TEXT_CRAS_NUMQUAM_SCIRE,
        delimiter: "en",
      })
    "sonnets" =>
      Some(BuiltinScheme::{ corpus: @ipsum.TEXT_SONNETS, delimiter: "en" })
    "xiaoyaoyou" =>
      Some(BuiltinScheme::{ corpus: @ipsum.TEXT_XIAOYAOYOU, delimiter: "zh" })
    "yau" => Some(BuiltinScheme::{ corpus: @ipsum.TEXT_YAU, delimiter: "zh" })
    _ => None
  }
}

///|
fn CallContext::compile_lorem(
  self : CallContext,
) -> Result[ElementOutput, Diagnostic] {
  let { call, context } = self

  compile_attrs(call.attrs, context.env).bind(attrs => {
    guard !call.children.is_empty() else {
      return Err(
        call.span.diagnostic(
          DiagnosticPhase::Type,
          "(lorem ...) requires a count",
        ),
      )
    }

    guard call.children[0] is Text(count, _) &&
      (Ok(@string.parse_int(count)) catch { e => Err(e) }) is Ok(count) else {
      return Err(
        call.span.diagnostic(
          DiagnosticPhase::Type,
          "lorem <count> requires an integer",
        ),
      )
    }

    let mut corpus = attrs.0
      .get("corpus")
      .bind(x => x)
      .unwrap_or(@ipsum.TEXT_LOREM)
    let mut delimiter = attrs.0.get("lang").bind(x => x).unwrap_or("en")

    if attrs.0
      .get("scheme")
      .bind(x => x)
      .map(name => BuiltinScheme::get(name))
      .bind(x => x)
      is Some(scheme) {
      corpus = scheme.corpus
      delimiter = scheme.delimiter
    }

    let seed = attrs.0
      .get("seed")
      .bind(x => x)
      .map(v => (Ok(@string.parse_int(v)) catch { e => Err(e) }).to_option())
      .bind(x => x)
      .unwrap_or(MAGIC_SEED_DEFAULT)

    let lorem = @ipsum.lorem(delimiter, corpus, count, seed)
    let html = HtmlNode::Element("span", @sexp.HtmlAttrs({}), [
      @sexp.Text(lorem),
    ])
    Ok(ElementOutput::body([html]))
  })
}
