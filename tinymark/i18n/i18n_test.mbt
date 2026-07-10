///|
test "normalizes builtin language aliases" {
  @test.assert_eq(normalize_builtin_language("cn"), "zh-Hans-CN")
  @test.assert_eq(normalize_builtin_language("hk"), "zh-Hant-HK")
  @test.assert_eq(normalize_builtin_language("tw"), "zh-Hant-TW")
  @test.assert_eq(normalize_builtin_language("ja"), "ja")
  @test.assert_eq(normalize_builtin_language("ko"), "ko")
  @test.assert_eq(normalize_builtin_language("en"), "en")
  @test.assert_eq(normalize_builtin_language("fr"), "fr")
  @test.assert_eq(normalize_builtin_language("de"), "de")
}

///|
test "builtin language set contains supported shorthand tags" {
  @test.assert_eq(builtin_languages.contains("cn"), true)
  @test.assert_eq(builtin_languages.contains("en"), true)
  @test.assert_eq(builtin_languages.contains("es"), false)
}
