///|
fn calculate_size(value : @katex.Measurement, options : Options) -> Double {
  let absolute : Double? = match value.unit {
    "pt" => Some(1.0)
    "mm" => Some(7227.0 / 2540.0)
    "cm" => Some(7227.0 / 254.0)
    "in" => Some(72.27)
    "bp" | "px" => Some(803.0 / 800.0)
    "pc" => Some(12.0)
    "dd" => Some(1238.0 / 1157.0)
    "cc" => Some(14856.0 / 1157.0)
    "nd" => Some(685.0 / 642.0)
    "nc" => Some(1370.0 / 107.0)
    "sp" => Some(1.0 / 65536.0)
    _ => None
  }
  let scale = absolute.map_or_else(
    () => {
      if value.unit == "mu" {
        options.metric("cssEmPerMu")
      } else {
        let unit_options = if options.style >= 4 {
          options.with_style(style_text(options.style))
        } else {
          options
        }
        let scale = unit_options.metric(
          if value.unit == "ex" {
            "xHeight"
          } else {
            "quad"
          },
        )
        scale * unit_options.size_multiplier / options.size_multiplier
      }
    },
    scale => scale / options.metric("ptPerEm") / options.size_multiplier,
  )
  (value.number * scale).min(options.max_size)
}

///|
fn make_em(value : Double) -> String {
  if value.abs() >= 100000000000000.0 || value.is_nan() {
    return value.to_string() + "em"
  }
  let bits = value.abs().reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7ff).to_int()
  let fraction_bits = bits & 0xfffffffffffff
  let significand = if exponent == 0 {
    fraction_bits
  } else {
    fraction_bits | (1 << 52)
  }
  let product = significand * 625
  let shift = if exponent == 0 { 1070 } else { 1071 - exponent }
  let scaled : UInt64 = if shift >= 64 {
    0
  } else {
    let remainder = product & ((1 << shift) - 1)
    (product >> shift) + (if remainder >= 1 << (shift - 1) { 1 } else { 0 })
  }
  if scaled == 0 {
    return "0em"
  }
  let integer = scaled / 10000
  let fraction = scaled % 10000
  let sign = if value < 0.0 { "-" } else { "" }
  if fraction == 0 {
    sign + integer.to_string() + "em"
  } else {
    let digits = fraction
      .to_string()
      .pad_start(4, '0')
      .trim_end(chars="0")
      .to_owned()
    sign + integer.to_string() + "." + digits + "em"
  }
}
