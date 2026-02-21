///|
pub(all) enum KatexConvertMode {
  AlwaysApp
  NeverApp
  AppWhenHasParens
} derive(Eq, Show, Debug)

///|
pub(all) struct MarkdownConvertOptions {
  convert_katex : KatexConvertMode
} derive(Eq, Show, Debug)

///|
pub let default_options : MarkdownConvertOptions = MarkdownConvertOptions::{
  convert_katex: AppWhenHasParens,
}
