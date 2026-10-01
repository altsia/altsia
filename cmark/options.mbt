///|
/// Option flags for the parser.
///
/// Bit values are a stable ABI, so option sets are interchangeable.
pub struct Options {
  mut flags : UInt
}

///|
pub fn Options::empty() -> Options {
  { flags: 0, }
}

///|
pub fn Options::insert(self : Options, other : Options) -> Unit {
  self.flags = self.flags | other.flags
}

///|
pub fn Options::contains(self : Options, other : Options) -> Bool {
  (self.flags & other.flags) == other.flags
}

///|
pub fn Options::is_empty(self : Options) -> Bool {
  self.flags == 0
}

///|
/// Enables GitHub-style tables.
pub fn enable_tables() -> Options {
  { flags: 1 << 1, }
}

///|
/// Enables GitHub-compatible footnote syntax.
pub fn enable_footnotes() -> Options {
  { flags: 1 << 2, }
}

///|
/// Enables strikethrough (GFM `~~x~~`).
pub fn enable_strikethrough() -> Options {
  { flags: 1 << 3, }
}

///|
/// Enables GitHub-style task lists.
pub fn enable_tasklists() -> Options {
  { flags: 1 << 4, }
}

///|
/// Enables smart punctuation.
pub fn enable_smart_punctuation() -> Options {
  { flags: 1 << 5, }
}

///|
/// Enables heading attributes (`# text {#id .class}`).
pub fn enable_heading_attributes() -> Options {
  { flags: 1 << 6, }
}

///|
/// Enables YAML-style metadata blocks.
pub fn enable_yaml_style_metadata_blocks() -> Options {
  { flags: 1 << 7, }
}

///|
/// Enables `+++`-delimited metadata blocks.
pub fn enable_pluses_delimited_metadata_blocks() -> Options {
  { flags: 1 << 8, }
}

///|
/// Enables the old (hoedown-style) footnote syntax. Implies `enable_footnotes`.
pub fn enable_old_footnotes() -> Options {
  { flags: (1 << 9) | (1 << 2), }
}

///|
/// Enables inline and display math.
pub fn enable_math() -> Options {
  { flags: 1 << 10, }
}

///|
/// Enables miscellaneous GFM features (blockquote tags).
pub fn enable_gfm() -> Options {
  { flags: 1 << 11, }
}

///|
/// Enables definition lists.
pub fn enable_definition_list() -> Options {
  { flags: 1 << 12, }
}

///|
/// Enables superscript.
pub fn enable_superscript() -> Options {
  { flags: 1 << 13, }
}

///|
/// Enables subscript.
pub fn enable_subscript() -> Options {
  { flags: 1 << 14, }
}

///|
/// Enables Obsidian-style wikilinks.
pub fn enable_wikilinks() -> Options {
  { flags: 1 << 15, }
}

///|
/// Enables colon-delimited container extension blocks.
pub fn enable_container_extensions() -> Options {
  { flags: 1 << 16, }
}

///|
/// Enables `==highlight==`.
pub fn enable_highlight() -> Options {
  { flags: 1 << 17, }
}

///|
/// Enables CJK-friendly emphasis.
pub fn enable_cjk_friendly_emphasis() -> Options {
  { flags: 1 << 18, }
}

///|
/// Enables treating every `$` as a math delimiter, regardless of surrounding
/// whitespace or digits. A literal `$` must be escaped as `\$`. Implies
/// `enable_math`.
pub fn enable_math_everywhere() -> Options {
  { flags: (1 << 19) | (1 << 10), }
}

///|
/// True when GFM-style footnotes are enabled (and old footnotes are not).
fn Options::options_has_gfm_footnotes(self : Options) -> Bool {
  self.contains(enable_footnotes()) && !self.contains(enable_old_footnotes())
}
