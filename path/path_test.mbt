// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "Path normalizes and strips local and external paths" {
  assert_eq(Path::normalize("notes\\./a/../b.alt"), "notes/b.alt")
  assert_eq(Path::normalize("/notes/../b.alt"), "/b.alt")
  assert_eq(
    Path::normalize("https://example.com/docs/a.alt"),
    "https://example.com/docs/a.alt",
  )
  assert_eq(
    Path::new("///notes/a.alt").strip_leading_slashes().as_string(),
    "notes/a.alt",
  )
}

///|
test "Path composes parent and join for relative targets" {
  assert_eq(Path::new("notes/a.alt").parent().as_string(), "notes")
  assert_eq(Path::new("/notes/a.alt").parent().as_string(), "/notes")
  assert_eq(Path::new("a.alt").parent().as_string(), "")

  assert_true(Path::new("./b.alt").is_relative())
  assert_false(Path::new("/b.alt").is_relative())
  assert_false(Path::new("https://example.com/b.alt").is_relative())

  assert_eq(
    Path::new("notes").join(Path::new("./b.alt")).as_string(),
    "notes/b.alt",
  )
  assert_eq(Path::new("notes").join(Path::new("../b.alt")).as_string(), "b.alt")
  assert_eq(Path::new("notes").join(Path::new("/b.alt")).as_string(), "/b.alt")
  assert_eq(
    Path::new("notes").join(Path::new("https://example.com/b.alt")).as_string(),
    "https://example.com/b.alt",
  )
}
