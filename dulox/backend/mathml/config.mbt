///|
/// Controls the outer MathML document.
pub struct RenderConfig {
  display_mode : Bool
  annotation : String?
} derive(Eq)

///|
pub fn RenderConfig::make(
  display_mode? : Bool = false,
  annotation? : String,
) -> RenderConfig {
  { display_mode, annotation, }
}

///|
pub impl Default for RenderConfig with fn default() {
  RenderConfig::make()
}

///|
priv struct RenderState {
  style : @katex.StyleLevel
  math_variant : String?
  text_family : String
  text_bold : Bool
  text_italic : Bool
  color : String?
}
