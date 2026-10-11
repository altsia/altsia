///|
pub struct RenderConfig {
  display_mode : Bool
  leqno : Bool
  fleqn : Bool
  max_size : Double
  min_rule_thickness : Double
} derive(Eq)

///|
pub fn RenderConfig::make(
  display_mode? : Bool = false,
  leqno? : Bool = false,
  fleqn? : Bool = false,
  max_size? : Double = 1.0 / 0.0,
  min_rule_thickness? : Double = 0.0,
) -> RenderConfig {
  { display_mode, leqno, fleqn, max_size, min_rule_thickness, }
}

///|
pub impl Default for RenderConfig with fn default() {
  RenderConfig::make()
}

///|
pub extend RenderConfig with Eq::{equal, not_equal}

///|
pub extend RenderConfig with Default::{default}
