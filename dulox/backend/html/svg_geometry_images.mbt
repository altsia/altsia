///|
fn stretchy_image_data(
  label : String,
) -> (Array[String], Double, Double, String) {
  match label {
    "overrightarrow" => (["rightarrow"], 0.888, 522.0, "xMaxYMin")
    "overleftarrow" => (["leftarrow"], 0.888, 522.0, "xMinYMin")
    "underrightarrow" => (["rightarrow"], 0.888, 522.0, "xMaxYMin")
    "underleftarrow" => (["leftarrow"], 0.888, 522.0, "xMinYMin")
    "xrightarrow" => (["rightarrow"], 1.469, 522.0, "xMaxYMin")
    "\\cdrightarrow" => (["rightarrow"], 3.0, 522.0, "xMaxYMin")
    "xleftarrow" => (["leftarrow"], 1.469, 522.0, "xMinYMin")
    "\\cdleftarrow" => (["leftarrow"], 3.0, 522.0, "xMinYMin")
    "Overrightarrow" => (["doublerightarrow"], 0.888, 560.0, "xMaxYMin")
    "xRightarrow" => (["doublerightarrow"], 1.526, 560.0, "xMaxYMin")
    "xLeftarrow" => (["doubleleftarrow"], 1.526, 560.0, "xMinYMin")
    "overleftharpoon" => (["leftharpoon"], 0.888, 522.0, "xMinYMin")
    "xleftharpoonup" => (["leftharpoon"], 0.888, 522.0, "xMinYMin")
    "xleftharpoondown" => (["leftharpoondown"], 0.888, 522.0, "xMinYMin")
    "overrightharpoon" => (["rightharpoon"], 0.888, 522.0, "xMaxYMin")
    "xrightharpoonup" => (["rightharpoon"], 0.888, 522.0, "xMaxYMin")
    "xrightharpoondown" => (["rightharpoondown"], 0.888, 522.0, "xMaxYMin")
    "xlongequal" => (["longequal"], 0.888, 334.0, "xMinYMin")
    "\\cdlongequal" => (["longequal"], 3.0, 334.0, "xMinYMin")
    "xtwoheadleftarrow" => (["twoheadleftarrow"], 0.888, 334.0, "xMinYMin")
    "xtwoheadrightarrow" => (["twoheadrightarrow"], 0.888, 334.0, "xMaxYMin")
    "overleftrightarrow" => (["leftarrow", "rightarrow"], 0.888, 522.0, "")
    "overbrace" => (["leftbrace", "midbrace", "rightbrace"], 1.6, 548.0, "")
    "underbrace" =>
      (["leftbraceunder", "midbraceunder", "rightbraceunder"], 1.6, 548.0, "")
    "underleftrightarrow" => (["leftarrow", "rightarrow"], 0.888, 522.0, "")
    "xleftrightarrow" => (["leftarrow", "rightarrow"], 1.75, 522.0, "")
    "xLeftrightarrow" =>
      (["doubleleftarrow", "doublerightarrow"], 1.75, 560.0, "")
    "xrightleftharpoons" =>
      (["leftharpoondownplus", "rightharpoonplus"], 1.75, 716.0, "")
    "xleftrightharpoons" =>
      (["leftharpoonplus", "rightharpoondownplus"], 1.75, 716.0, "")
    "xhookleftarrow" => (["leftarrow", "righthook"], 1.08, 522.0, "")
    "xhookrightarrow" => (["lefthook", "rightarrow"], 1.08, 522.0, "")
    "overlinesegment" =>
      (["leftlinesegment", "rightlinesegment"], 0.888, 522.0, "")
    "underlinesegment" =>
      (["leftlinesegment", "rightlinesegment"], 0.888, 522.0, "")
    "overbracket" => (["leftbracketover", "rightbracketover"], 1.6, 440.0, "")
    "underbracket" =>
      (["leftbracketunder", "rightbracketunder"], 1.6, 410.0, "")
    "overgroup" => (["leftgroup", "rightgroup"], 0.888, 342.0, "")
    "undergroup" => (["leftgroupunder", "rightgroupunder"], 0.888, 342.0, "")
    "xmapsto" => (["leftmapsto", "rightarrow"], 1.5, 522.0, "")
    "xtofrom" => (["leftToFrom", "rightToFrom"], 1.75, 528.0, "")
    "xrightleftarrows" =>
      (["baraboveleftarrow", "rightarrowabovebar"], 1.75, 901.0, "")
    "xrightequilibrium" =>
      (
        ["baraboveshortleftharpoon", "rightharpoonaboveshortbar"],
        1.75,
        716.0,
        "",
      )
    "xleftequilibrium" =>
      (
        ["shortbaraboveleftharpoon", "shortrightharpoonabovebar"],
        1.75,
        716.0,
        "",
      )
    _ => ([], 0.0, 0.0, "")
  }
}
