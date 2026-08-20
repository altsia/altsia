///|
pub struct TaxonKey {
  value : String
} derive(Eq, Debug)

///|
pub extend TaxonKey with Eq::{not_equal, equal}

///|
pub extend TaxonKey with Debug::{to_repr}

///|
pub fn TaxonKey::new(value : String) -> TaxonKey {
  { value: value.trim().to_owned().to_lower() }
}

///|
pub struct Taxon {
  key : TaxonKey
  display : String?
} derive(Eq, Debug)

///|
pub extend Taxon with Eq::{not_equal, equal}

///|
pub extend Taxon with Debug::{to_repr}

///|
pub fn Taxon::new(key : String, display? : String) -> Taxon {
  { key: TaxonKey::new(key), display }
}

///|
pub fn Taxon::with_display(self : Taxon, display : String) -> Taxon {
  { ..self, display: Some(display) }
}

///|
pub fn Taxon::data_key(self : Taxon) -> String {
  self.key.value
}

///|
pub fn Taxon::display(self : Taxon, lang : String?) -> String {
  match self.display {
    Some(value) => value
    None => default_taxon_display(self.key, lang)
  }
}

///|
pub fn Taxon::is_reference(self : Taxon) -> Bool {
  self.key.value == "reference"
}

///|
fn default_taxon_display(key : TaxonKey, lang : String?) -> String {
  let language = lang.unwrap_or("en").to_lower()
  if language.has_prefix("zh") {
    match key.value {
      "axiom" => "公理"
      "claim" => "断言"
      "conjecture" => "猜想"
      "corollary" => "推论"
      "definition" => "定义"
      "example" => "例子"
      "fact" => "事实"
      "hypothesis" => "假设"
      "lemma" => "引理"
      "observation" => "观察"
      "person" => "人物"
      "postulate" => "公设"
      "proof" => "证明"
      "proposition" => "命题"
      "reference" => "参考"
      "remark" => "注记"
      "theorem" => "定理"
      _ => key.value
    }
  } else {
    english_taxon_display(key.value)
  }
}

///|
fn english_taxon_display(key : String) -> String {
  let text = key.replace_all(old="-", new=" ").replace_all(old="_", new=" ")
  guard text.length() != 0 else { "" }
  "\{text.unsafe_substring(start=0, end=1).to_upper()}\{text.unsafe_substring(start=1, end=text.length())}. "
}
