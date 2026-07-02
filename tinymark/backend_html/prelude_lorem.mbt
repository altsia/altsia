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
