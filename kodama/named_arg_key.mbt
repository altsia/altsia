///|
/// Normalize named app argument keys to the `:name` form.
fn normalize_named_arg_key(name : String) -> String {
  if name.has_prefix(":") {
    name
  } else {
    ":\{name}"
  }
}
