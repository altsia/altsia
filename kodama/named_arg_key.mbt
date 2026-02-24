// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
/// Normalize named app argument keys to the `:name` form.
fn normalize_named_arg_key(name : String) -> String {
  if name.has_prefix(":") {
    name
  } else {
    ":\{name}"
  }
}
