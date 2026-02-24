// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
pub const DEFAULT_FORMAT : String = "MMMM D, YYYY"

///|
fn month_name(month : Int) -> String {
  match month {
    1 => "January"
    2 => "February"
    3 => "March"
    4 => "April"
    5 => "May"
    6 => "June"
    7 => "July"
    8 => "August"
    9 => "September"
    10 => "October"
    11 => "November"
    12 => "December"
    _ => "InvalidMonth"
  }
}

///|
fn month_short_name(month : Int) -> String {
  match month {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    12 => "Dec"
    _ => "Inv"
  }
}

///|
fn two_digit(n : Int) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    "\{n}"
  }
}

///|
fn civil_from_days(days_since_epoch : Int) -> (Int, Int, Int) {
  // Howard Hinnant's civil date algorithm, using Unix epoch day as input.
  let z = days_since_epoch + 719468
  let era = if z >= 0 { z / 146097 } else { (z - 146096) / 146097 }
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let mut year = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let day = doy - (153 * mp + 2) / 5 + 1
  let month = mp + (if mp < 10 { 3 } else { -9 })
  if month <= 2 {
    year += 1
  }
  (year, month, day)
}

///|
fn format_date_by_pattern(
  year : Int,
  month : Int,
  day : Int,
  pattern : String,
) -> String {
  let rendered : Array[String] = []
  let mut rest = pattern[:]
  while !rest.is_empty() {
    if rest.has_prefix("YYYY") {
      rendered.push(year.to_string())
      rest = rest.view(start_offset=4)
    } else if rest.has_prefix("YY") {
      rendered.push(two_digit(year % 100))
      rest = rest.view(start_offset=2)
    } else if rest.has_prefix("MMMM") {
      rendered.push(month_name(month))
      rest = rest.view(start_offset=4)
    } else if rest.has_prefix("MMM") {
      rendered.push(month_short_name(month))
      rest = rest.view(start_offset=3)
    } else if rest.has_prefix("MM") {
      rendered.push(two_digit(month))
      rest = rest.view(start_offset=2)
    } else if rest.has_prefix("M") {
      rendered.push(month.to_string())
      rest = rest.view(start_offset=1)
    } else if rest.has_prefix("DD") {
      rendered.push(two_digit(day))
      rest = rest.view(start_offset=2)
    } else if rest.has_prefix("D") {
      rendered.push(day.to_string())
      rest = rest.view(start_offset=1)
    } else {
      let next_offset = match rest.offset_of_nth_char(1) {
        Some(offset) => offset
        None => rest.length()
      }
      rendered.push(rest.view(end_offset=next_offset).to_string())
      rest = rest.view(start_offset=next_offset)
    }
  }
  rendered.join("")
}

///|
pub fn format_unix_millis_date(
  unix_millis : UInt64,
  format? : String = DEFAULT_FORMAT,
) -> String {
  let millis_per_day = UInt64::extend_uint(86400000)
  let days_since_epoch = (unix_millis / millis_per_day).to_int()
  let (year, month, day) = civil_from_days(days_since_epoch)
  format_date_by_pattern(year, month, day, format)
}
