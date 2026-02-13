///|
pub(all) struct SourceLoc {
  start_offset : Int
  end_offset : Int
  line : Int
  column : Int
} derive(Eq, Show, Debug)

///|
fn source_char_at(source : String, i : Int) -> Char {
  source.get_char(i).unwrap()
}

fn line_column_at(source : String, offset : Int) -> (Int, Int) {
  let clamped = if offset < 0 {
    0
  } else if offset > source.length() {
    source.length()
  } else {
    offset
  }
  let mut line = 1
  let mut column = 1
  for i in 0..<clamped {
    if source_char_at(source, i) == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  (line, column)
}

///|
pub fn source_loc_from_offsets(
  source : String,
  start_offset : Int,
  end_offset : Int,
) -> SourceLoc {
  let safe_start = if start_offset < 0 {
    0
  } else if start_offset > source.length() {
    source.length()
  } else {
    start_offset
  }
  let safe_end = if end_offset < safe_start {
    safe_start
  } else if end_offset > source.length() {
    source.length()
  } else {
    end_offset
  }
  let (line, column) = line_column_at(source, safe_start)
  { start_offset: safe_start, end_offset: safe_end, line, column }
}
