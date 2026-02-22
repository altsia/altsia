///|
pub const KEY_TITLE : String = "title"

///|
/// Auto-detected
pub const KEY_SLUG : String = "slug"

///|
pub const KEY_TAXON : String = "taxon"

///|
pub let fancy_metadata_keys : Array[String] = [KEY_TITLE, KEY_TAXON]

///|
pub fn is_fancy_metadata(key : String) -> Bool {
  fancy_metadata_keys.contains(key)
}

