///|
test "watch directory uses current directory for a bare input filename" {
  @test.assert_eq(watch_directory("file.alt"), ".")
}

///|
test "watch directory normalizes an explicit relative directory" {
  @test.assert_eq(watch_directory("./file.alt"), ".")
}
