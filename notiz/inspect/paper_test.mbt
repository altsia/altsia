///|
test "from_string parses paper sizes" {
  @test.assert_eq(@parsing.Paper::from_string("a4"), Ok(@parsing.Paper::A4))
  @test.assert_eq(
    @parsing.Paper::from_string("unknown"),
    Err("unknown paper size: unknown"),
  )
}
