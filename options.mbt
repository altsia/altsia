// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
pub struct HtmlComposeOptions {
  extern_api : Bool
  comment_strip : Bool
  markdown_abbrev : Bool
}

///|
fn html_compose_options_default() -> HtmlComposeOptions {
  HtmlComposeOptions::{
    extern_api: false,
    comment_strip: true,
    markdown_abbrev: false,
  }
}

///|
fn html_compose_enable_all() -> HtmlComposeOptions {
  HtmlComposeOptions::{
    extern_api: true,
    comment_strip: true,
    markdown_abbrev: true,
  }
}
