///|
#alias(today)
pub fn format_now_date(format? : String = DEFAULT_FORMAT) -> String {
  format_unix_millis_date(@env.now(), format~)
}
