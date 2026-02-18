///|
pub fn altsia_normalize(
  source : String,
  language? : String = @core.default_language,
  max_width? : Int = @core.default_max_width,
) -> String {
  match @core.altsia_normalize_result(source, language~, max_width~) {
    Ok(normalized) => normalized
    Err(errors) => errors.join("\n")
  }
}

///|
pub fn altsia_normalize_range(
  source : String,
  start_offset : Int,
  end_offset : Int,
  language? : String = @core.default_language,
  max_width? : Int = @core.default_max_width,
) -> String {
  match
    @core.altsia_normalize_range_result(
      source,
      start_offset,
      end_offset,
      language~,
      max_width~,
    ) {
    Ok(normalized) => normalized
    Err(errors) => errors.join("\n")
  }
}
