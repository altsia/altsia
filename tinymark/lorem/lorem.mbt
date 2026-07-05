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
pub fn compile_lorem_text(
  attrs : Array[@core.Attr],
  children : Array[@core.Node],
  env : @core.CompileEnv,
  span : @core.SourceSpan,
) -> Result[String, @core.Diagnostic] {
  guard !children.is_empty() else {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::Type,
        "(lorem ...) requires a count",
      ),
    )
  }

  guard children[0] is @core.Node::Text(count, _) &&
    (Ok(@string.parse_int(count)) catch { e => Err(e) }) is Ok(count) else {
    return Err(
      span.diagnostic(
        @core.DiagnosticPhase::Type,
        "lorem <count> requires an integer",
      ),
    )
  }

  let options = match LoremOptions::from_attrs(attrs, env) {
    Ok(options) => options
    Err(error) => return Err(error)
  }
  Ok(@ipsum.lorem(options.delimiter, options.corpus, count, options.seed))
}

///|
priv struct LoremOptions {
  corpus : String
  delimiter : String
  seed : Int
}

///|
fn LoremOptions::default() -> LoremOptions {
  { corpus: @ipsum.TEXT_LOREM, delimiter: "en", seed: MAGIC_SEED_DEFAULT }
}

///|
fn LoremOptions::from_attrs(
  attrs : Array[@core.Attr],
  env : @core.CompileEnv,
) -> Result[LoremOptions, @core.Diagnostic] {
  let mut options = LoremOptions::default()
  for attr in attrs {
    let value = match attr.value {
      Some(value) =>
        match value.to_scalar(env) {
          Err(error) => return Err(error)
          Ok(value) => Some(value)
        }
      None => None
    }
    match attr.name {
      "corpus" => if value is Some(corpus) { options = { ..options, corpus, } }
      "lang" =>
        if value is Some(delimiter) {
          options = { ..options, delimiter, }
        }
      "scheme" =>
        if value is Some(name) && BuiltinScheme::get(name) is Some(scheme) {
          options = {
            ..options,
            corpus: scheme.corpus,
            delimiter: scheme.delimiter,
          }
        }
      "seed" =>
        if value is Some(seed) {
          options = {
            ..options,
            seed: (Ok(@string.parse_int(seed)) catch { _ => Err(()) }).unwrap_or(
              MAGIC_SEED_DEFAULT,
            ),
          }
        }
      _ => ()
    }
  }
  Ok(options)
}
