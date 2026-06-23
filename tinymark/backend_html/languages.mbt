///|
pub type LanguageTag = String

///|
pub let builtin_languages : @immut_set.HashSet[LanguageTag] = @immut_set.HashSet::from_array([
    "cn", "hk", "tw", "ja", "ko", "en", "fr", "de",
  ],
)

///|
pub fn normalize_bcp47(tag : LanguageTag) -> String {
  match tag {
    "cn" => "zh-Hans-CN"
    "hk" => "zh-Hans-HK"
    "tw" => "zh-Hant-TW"
    _ => tag
  }
}
