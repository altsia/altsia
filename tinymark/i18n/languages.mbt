///|
pub let builtin_languages : @hashset.HashSet[String] = @hashset.HashSet([
  "cn", "hk", "tw", "ja", "ko", "en", "fr", "de",
])

///|
pub fn normalize_builtin_language(tag : String) -> String {
  match tag {
    "cn" => "zh-Hans-CN"
    "hk" => "zh-Hant-HK"
    "tw" => "zh-Hant-TW"
    _ => tag
  }
}
