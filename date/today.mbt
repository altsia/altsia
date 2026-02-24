// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
#alias(today)
pub fn format_now_date(format? : String = DEFAULT_FORMAT) -> String {
  format_unix_millis_date(@env.now(), format~)
}
