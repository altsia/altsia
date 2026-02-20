///|
priv struct HtmlComposeOptions {
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
fn html_compose_options_for_rewriter() -> HtmlComposeOptions {
  HtmlComposeOptions::{
    extern_api: true,
    comment_strip: true,
    markdown_abbrev: true,
  }
}
