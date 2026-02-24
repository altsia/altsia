// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

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
