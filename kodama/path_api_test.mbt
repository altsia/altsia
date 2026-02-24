// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
test "Kodama path api derives slug from doc id" {
  assert_eq(path_to_slug(@path.Path::new("docs/intro.alt")), "docs/intro")
  assert_eq(path_to_slug(@path.Path::new("/trees/CN2E.alt")), "/trees/CN2E")
}
