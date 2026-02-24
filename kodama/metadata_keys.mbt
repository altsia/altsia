// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
pub const KEY_TITLE : String = "title"

///|
/// User-provided plain-text title for text-only contexts (e.g. HTML title attr).
pub const KEY_PAGE_TITLE : String = "page-title"

///|
/// Auto-detected
pub const KEY_SLUG : String = "slug"

///|
pub const KEY_TAXON : String = "taxon"

///|
pub type PresetKeys = @immut_hashset.HashSet[String]

///|
pub let metadata_preset_keys : PresetKeys = PresetKeys::from_array([
  KEY_TITLE,
  KEY_PAGE_TITLE,
  KEY_TAXON,
  KEY_SLUG,
])

///|
pub type MetadataKey

///|
pub fn MetadataKey::is_preset(key : String) -> Bool {
  metadata_preset_keys.contains(key)
}
