// Copyright (c) 2025 Altsia Project. All rights reserved.
// Released under the GPL-3.0 license as described in the file LICENSE.
// Authors: Kokic (@kokic)

///|
/// specialize `Some(s).filter(s => !s.is_empty())`
pub fn non_empty(s : String) -> String? {
  guard s.is_empty() else { Some(s) }
  None
}
