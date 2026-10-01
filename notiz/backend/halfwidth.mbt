///|
/// Replaces the minimal set of full-width punctuation with half-width
/// equivalents: `，` `。` `！` `？` `：` `；` `（` `）` `“”` `‘’` become `,`
/// `.` `!` `?` `:` `;` `(` `)` `"` `'`.
///
/// Converted punctuation is spaced apart from its neighbors: every converted
/// punctuation except the opening bracket `（` and the opening quotes `“` `‘`
/// gains a trailing space when a non-whitespace, non-punctuation character
/// follows, and the opening bracket and quotes gain a leading space when a
/// non-whitespace, non-punctuation character precedes them. Full-width
/// punctuation counts as punctuation for this purpose, so adjacent converted
/// punctuation stays tight: `你好（世界）！` renders as `你好 (世界)!`,
/// `（世界）。` renders as `(世界).`, while `a，!b` renders as `a, !b`. `prev`
/// and `next` supply the neighboring characters when `s` is rendered as part
/// of a longer run that starts or ends outside `s`.
///
/// A link destination `(url)` right after `](` is copied unchanged so
/// punctuation inside URLs is preserved. All other characters are kept
/// unchanged.
fn to_halfwidth_punct(
  s : String,
  prev? : Char? = None,
  next? : Char? = None,
) -> String {
  let chars = s.iter().to_array()
  let buf = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ']' && i + 1 < chars.length() && chars[i + 1] == '(' {
      buf.write_char(']')
      i += 1
      while i < chars.length() {
        let u = chars[i]
        buf.write_char(u)
        i += 1
        if u == ')' {
          break
        }
      }
      continue
    }
    let converted = match c {
      '，' => ','
      '。' => '.'
      '！' => '!'
      '？' => '?'
      '：' => ':'
      '；' => ';'
      '（' => '('
      '）' => ')'
      '“' | '”' => '"'
      '‘' | '’' => '\''
      _ => c
    }
    let is_open = c == '（' || c == '“' || c == '‘'
    let lead_space = is_open &&
      (if i > 0 {
        !chars[i - 1].is_whitespace() && !is_spacing_punct(chars[i - 1])
      } else {
        match prev {
          Some(p) => !p.is_whitespace() && !is_spacing_punct(p)
          None => false
        }
      })
    if lead_space {
      buf.write_char(' ')
    }
    buf.write_char(converted)
    let trail_space = converted != c &&
      !is_open &&
      (if i + 1 < chars.length() {
        !chars[i + 1].is_whitespace() && !is_spacing_punct(chars[i + 1])
      } else {
        match next {
          Some(n) => !n.is_whitespace() && !is_spacing_punct(n)
          None => false
        }
      })
    if trail_space {
      buf.write_char(' ')
    }
    i += 1
  }
  buf.to_string()
}

///|
fn is_spacing_punct(c : Char) -> Bool {
  match c {
    '，'
    | '。'
    | '！'
    | '？'
    | '：'
    | '；'
    | '（'
    | '）'
    | '“'
    | '”'
    | '‘'
    | '’' => true
    _ => false
  }
}
