///|
test "format_unix_millis_date uses default long month format" {
  let unix_epoch : UInt64 = 0
  assert_eq(format_unix_millis_date(unix_epoch), "January 1, 1970")
}

///|
test "format_unix_millis_date formats known date" {
  let ts : UInt64 = 1634947200000
  assert_eq(format_unix_millis_date(ts), "October 23, 2021")
}

///|
test "format_unix_millis_date handles leap day" {
  let ts : UInt64 = 1709164800000
  assert_eq(format_unix_millis_date(ts), "February 29, 2024")
}

///|
test "format_unix_millis_date supports YYYY-MM-DD pattern" {
  let ts : UInt64 = 1634947200000
  assert_eq(format_unix_millis_date(ts, format="YYYY-MM-DD"), "2021-10-23")
}

///|
test "format_unix_millis_date supports short month and two-digit year pattern" {
  let ts : UInt64 = 1634947200000
  assert_eq(format_unix_millis_date(ts, format="MMM D, YY"), "Oct 23, 21")
}

///|
test "format_unix_millis_date keeps non-token characters in custom pattern" {
  let ts : UInt64 = 1634947200000
  assert_eq(format_unix_millis_date(ts, format="YYYY年M月D日"), "2021年10月23日")
}

