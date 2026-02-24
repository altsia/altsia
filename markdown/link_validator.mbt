// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
fn has_any_prefix(link : String, prefixes : Array[String]) -> Bool {
  prefixes.iter().any(prefix => link.has_prefix(prefix))
}

///|
pub fn is_external_link(link : String) -> Bool {
  has_any_prefix(link, [
    "http://", "https://", "www.", "mailto:", "file://", "ftp://", "ftps://", "irc://",
    "tel:", "sms:", "data:", "blob:", "//",
  ])
}

///|
pub fn is_assets_link(link : String) -> Bool {
  link.has_prefix("assets/") || link.has_prefix("/assets/")
}

///|
pub fn is_inline_typst(link : String) -> Bool {
  link == "inline" || link.has_prefix("inline-")
}

///|
pub fn is_local_link(link : String) -> Bool {
  !link.has_suffix("//") &&
  !is_external_link(link) &&
  !is_assets_link(link) &&
  !is_inline_typst(link) &&
  !link.contains(":")
}
