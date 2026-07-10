///|
pub let builtin_languages : @hashset.HashSet[String] = @hashset.HashSet([
  "cn", "hk", "tw", "ja", "ko", "en", "fr", "de",
])

///|
pub fn normalize_builtin_language(tag : String) -> String {
  // cn/hk/tw are Tinymark shorthands for Chinese variants rather than
  // valid BCP 47 language tags. The other builtins (ja/ko/en/fr/de) are
  // already valid primary language subtags, so they are kept as-is.
  match tag {
    "cn" => "zh-Hans-CN"
    "hk" => "zh-Hant-HK"
    "tw" => "zh-Hant-TW"
    _ => tag
  }
}
