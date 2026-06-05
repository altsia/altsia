///|
test "finds project root from altsia.toml" {
  let root = "/private/tmp/altsia-root-test"
  @fs.create_dir(root) catch {
    IOError(_) => ()
  }
  @fs.write_string_to_file(root + "/altsia.toml", "")
  match find_project_root(root + "/nested") {
    Some(config) => @test.assert_eq(config.root, root)
    None => abort("expected project root")
  }
}
