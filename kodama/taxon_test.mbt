// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "Taxon text_transform keeps empty text" {
  assert_eq(Taxon::text_transform(""), "")
}

///|
test "Taxon text_transform uppercases first ASCII character only" {
  assert_eq(Taxon::text_transform("lemma"), "Lemma")
}

///|
test "Taxon text_transform uppercases first Unicode character when possible" {
  assert_eq(Taxon::text_transform("école"), "École")
}

///|
test "Taxon text_transform keeps first Unicode character without uppercase form" {
  assert_eq(Taxon::text_transform("中文"), "中文")
}

///|
test "Taxon text_transform handles non-BMP first character boundary" {
  assert_eq(Taxon::text_transform("😀lemma"), "😀lemma")
}
