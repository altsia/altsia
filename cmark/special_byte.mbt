//! Special-byte handling for `parse_line`.

///|
fn FirstPass::handle_special_byte(
  self : FirstPass,
  ix : Int,
  byte : Byte,
  mode : TableParseMode,
  limit : Int,
  bytes_len : Int,
  start : Int,
  state : LineState,
) -> (ParseLineAction, LineState) {
  self.handle_special_byte_inner(ix, byte, mode, limit, bytes_len, start, state)
}

///|
fn FirstPass::handle_special_byte_inner(
  self : FirstPass,
  ix : Int,
  byte : Byte,
  mode : TableParseMode,
  limit : Int,
  bytes_len : Int,
  start : Int,
  state : LineState,
) -> (ParseLineAction, LineState) {
  let bytes = self.text
  match byte {
    b'\n' | b'\r' => {
      guard !is_active_mode(mode) else {
        return (ParseLineAction::BreakWith(ix, None), state)
      }

      let mut i = ix
      let eol_bytes = scan_eol(bytes.exact_view(start=ix)).unwrap()

      let end_ix = ix + eol_bytes
      let trailing_backslashes = scan_rev_while(bytes.exact_view(start=0, end=ix), b => {
        b == b'\\'
      })
      if trailing_backslashes % 2 == 1 && end_ix < bytes_len {
        i -= 1
        self.tree.append_text(state.begin_text, i, state.backslash_escaped)
        state.backslash_escaped = false
        return (
          ParseLineAction::BreakWith(
            end_ix,
            Some(Item::{ start: i, end: end_ix, body: HardBreak(true), }),
          ),
          state,
        )
      }

      let is_scan = is_scan_mode(mode)
      if is_scan && state.pipes > 0 {
        // check if we may be parsing a table
        let next_line_ix = ix + eol_bytes
        let line_start = LineStart::new(bytes.exact_view(start=next_line_ix))
        if line_start.scan_containers(self.tree, self.options) ==
          self.tree.spine_len() {
          let table_head_ix = next_line_ix + line_start.bytes_scanned()
          let (table_head_bytes, alignment) = scan_table_head(
            bytes.exact_view(start=table_head_ix),
          )

          if table_head_bytes > 0 {
            // computing header count from number of pipes
            let header_count = count_header_cols(
              bytes,
              state.pipes,
              start,
              state.last_pipe_ix,
            )

            // make sure they match the number of columns
            if alignment.length() == header_count {
              let alignment_ix = self.allocs.allocate_alignment(alignment)
              let end_ix = table_head_ix + table_head_bytes
              return (
                ParseLineAction::BreakWith(
                  end_ix,
                  Some(Item::{
                    start: i,
                    end: end_ix,
                    body: Table(alignment_ix),
                  }),
                ),
                state,
              )
            }
          }
        }
      }

      let trailing_whitespace = scan_rev_while(bytes.exact_view(start=0, end=ix), c => {
        c.is_ascii_whitespace_no_nl()
      })
      if trailing_whitespace >= 2 {
        i -= trailing_whitespace
        self.tree.append_text(state.begin_text, i, state.backslash_escaped)
        state.backslash_escaped = false
        return (
          ParseLineAction::BreakWith(
            end_ix,
            Some(Item::{ start: i, end: end_ix, body: HardBreak(false), }),
          ),
          state,
        )
      }

      self.tree.append_text(
        state.begin_text,
        ix - trailing_whitespace,
        state.backslash_escaped,
      )
      state.backslash_escaped = false

      (
        ParseLineAction::BreakWith(
          end_ix,
          Some(Item::{ start: i, end: end_ix, body: SoftBreak, }),
        ),
        state,
      )
    }
    b'\\' => {
      let is_escape = ix + 1 < limit &&
        is_ascii_punctuation(bytes.unsafe_get(ix + 1).to_int())
      guard is_escape else { return (ParseLineAction::Continue(0), state) }
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      if bytes.unsafe_get(ix + 1) == b'`' {
        let count = 1 + scan_ch_repeat(bytes.exact_view(start=ix + 2), b'`')
        ignore(
          self.tree.append(Item::{
            start: ix + 1,
            end: ix + count + 1,
            body: MaybeCode(count, true),
          }),
        )
        state.begin_text = ix + 1 + count
        state.backslash_escaped = false
        (ParseLineAction::Continue(count), state)
      } else {
        let in_table = is_active_mode(mode)
        if bytes.unsafe_get(ix + 1) == b'|' && in_table {
          // backslash escaped pipes in tables aren't "real" backslash escapes
          state.begin_text = ix + 1
          state.backslash_escaped = false
          (ParseLineAction::Continue(1), state)
        } else {
          let is_double_escape = ix + 2 < limit &&
            bytes.unsafe_get(ix + 1) == b'\\' &&
            bytes.unsafe_get(ix + 2) == b'|' &&
            in_table
          if is_double_escape {
            // To parse `\\|`, discard the backslashes and parse the `|` that follows it.
            state.begin_text = ix + 2
            state.backslash_escaped = true
            (ParseLineAction::Continue(2), state)
          } else {
            state.begin_text = ix + 1
            state.backslash_escaped = true
            (ParseLineAction::Continue(1), state)
          }
        }
      }
    }
    b'*' | b'_' | b'~' | b'^' | b'=' => {
      let count = 1 + scan_ch_repeat(bytes.exact_view(start=ix + 1), byte)
      let can_open = delim_run_can_open(
        self.text,
        start,
        ix,
        count,
        mode,
        self.options,
      )
      let can_close = delim_run_can_close(
        self.text,
        start,
        ix,
        count,
        mode,
        self.options,
      )
      let is_valid_seq = match byte {
        b'~' => count <= 2
        b'=' => count == 2
        _ => true
      }

      if (can_open || can_close) && is_valid_seq {
        self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
        state.backslash_escaped = false
        for k in 0..<count {
          ignore(
            self.tree.append(Item::{
              start: ix + k,
              end: ix + k + 1,
              body: MaybeEmphasis(count - k, can_open, can_close),
            }),
          )
        }
        state.begin_text = ix + count
      }
      (ParseLineAction::Continue(count - 1), state)
    }
    b'$' => {
      let byte_suffix = bytes.exact_view(start=ix)
      let can_open = self.options.contains(enable_math_everywhere()) ||
        byte_suffix.length() < 2 ||
        !byte_suffix.unsafe_get(1).to_char().is_ascii_whitespace()
      let can_close = self.options.contains(enable_math_everywhere()) ||
        (
          ix > start &&
          !bytes.unsafe_get(ix - 1).to_char().is_ascii_whitespace() &&
          !(ix + 1 < limit &&
          bytes.unsafe_get(ix + 1).to_char().is_ascii_digit())
        )

      // 0xFF represents the root brace context
      let brace_context = if self.brace_context_stack.length() >
        MATH_BRACE_CONTEXT_MAX_NESTING {
        self.brace_context_next & 0xff
      } else {
        match self.brace_context_stack.last() {
          Some(v) => v
          None => {
            self.brace_context_stack.push(0xff)
            0xff
          }
        }
      }

      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + 1,
          body: MaybeMath(can_open, can_close, brace_context),
        }),
      )
      state.begin_text = ix + 1
      (ParseLineAction::Continue(0), state)
    }
    b'{' => {
      if self.brace_context_stack.length() == MATH_BRACE_CONTEXT_MAX_NESTING {
        self.brace_context_stack.push(self.brace_context_next & 0xff)
        self.brace_context_next = MATH_BRACE_CONTEXT_MAX_NESTING
      } else if self.brace_context_stack.length() >
        MATH_BRACE_CONTEXT_MAX_NESTING {
        // When we reach the limit of nesting, switch from actually matching
        // braces to just counting them.
        self.brace_context_next += 1
      } else if !self.brace_context_stack.is_empty() {
        // Store nothing if no math environment has been reached yet.
        self.brace_context_stack.push(self.brace_context_next & 0xff)
        self.brace_context_next += 1
      }
      (ParseLineAction::Continue(0), state)
    }
    b'}' => {
      if self.brace_context_stack.length() == 1 {
        // Unbalanced Braces
        self.brace_context_stack[0] = (self.brace_context_stack[0] - 1) & 0xff
      } else if self.brace_context_stack.length() >
        MATH_BRACE_CONTEXT_MAX_NESTING {
        if self.brace_context_next <= MATH_BRACE_CONTEXT_MAX_NESTING {
          ignore(self.brace_context_stack.pop())
        } else {
          self.brace_context_next -= 1
        }
      } else {
        ignore(self.brace_context_stack.pop())
      }
      (ParseLineAction::Continue(0), state)
    }
    b'`' => {
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      let count = 1 + scan_ch_repeat(bytes.exact_view(start=ix + 1), b'`')
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + count,
          body: MaybeCode(count, false),
        }),
      )
      state.begin_text = ix + count
      (ParseLineAction::Continue(count - 1), state)
    }
    b'<' => {
      let not_backslash = limit <= ix + 1 || bytes.unsafe_get(ix + 1) != b'\\'
      guard not_backslash else { return (ParseLineAction::Continue(0), state) }
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{ start: ix, end: ix + 1, body: MaybeHtml, }),
      )
      state.begin_text = ix + 1
      (ParseLineAction::Continue(0), state)
    }
    b'!' => {
      guard ix + 1 < limit && bytes.unsafe_get(ix + 1) == b'[' else {
        return (ParseLineAction::Continue(0), state)
      }
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{ start: ix, end: ix + 2, body: MaybeImage, }),
      )
      state.begin_text = ix + 2
      (ParseLineAction::Continue(1), state)
    }
    b'[' => {
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{ start: ix, end: ix + 1, body: MaybeLinkOpen, }),
      )
      state.begin_text = ix + 1
      (ParseLineAction::Continue(0), state)
    }
    b']' => {
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + 1,
          body: MaybeLinkClose(true),
        }),
      )
      state.begin_text = ix + 1
      (ParseLineAction::Continue(0), state)
    }
    b'&' => {
      guard scan_entity(bytes.exact_view(start=ix)) is (n, Some(value)) else {
        return (ParseLineAction::Continue(0), state)
      }
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + n,
          body: SynthesizeText(self.allocs.allocate_cow(value)),
        }),
      )
      state.begin_text = ix + n
      (ParseLineAction::Continue(n - 1), state)
    }
    b'|' =>
      if ix != 0 && bytes.unsafe_get(ix - 1) == b'\\' {
        (ParseLineAction::Continue(0), state)
      } else {
        let in_table = is_active_mode(mode)
        if in_table {
          (ParseLineAction::BreakWith(ix, None), state)
        } else {
          state.last_pipe_ix = ix
          state.pipes += 1
          (ParseLineAction::Continue(0), state)
        }
      }
    b'.' => {
      let is_ellipsis = ix + 2 < limit &&
        bytes.unsafe_get(ix + 1) == b'.' &&
        bytes.unsafe_get(ix + 2) == b'.'
      guard is_ellipsis else { return (ParseLineAction::Continue(0), state) }
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + 3,
          body: SynthesizeChar('…'),
        }),
      )
      state.begin_text = ix + 3
      (ParseLineAction::Continue(2), state)
    }
    b'-' => {
      let count = 1 + scan_ch_repeat(bytes.exact_view(start=ix + 1), b'-')
      if count == 1 {
        (ParseLineAction::Continue(0), state)
      } else {
        let itembody = if count == 2 {
          SynthesizeChar('–')
        } else if count == 3 {
          SynthesizeChar('—')
        } else {
          let (ems, ens) = match count % 6 {
            0 | 3 => (count / 3, 0)
            2 | 4 => (0, count / 2)
            1 => (count / 3 - 1, 2)
            _ => (count / 3, 1)
          }
          // – and — are 3 bytes each in utf8
          let buf = StringBuilder()
          for _ in 0..<ems {
            buf.write_char('—')
          }
          for _ in 0..<ens {
            buf.write_char('–')
          }
          SynthesizeText(self.allocs.allocate_cow(buf.to_string()))
        }

        self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
        state.backslash_escaped = false
        ignore(
          self.tree.append(Item::{ start: ix, end: ix + count, body: itembody, }),
        )
        state.begin_text = ix + count
        (ParseLineAction::Continue(count - 1), state)
      }
    }
    b'\'' | b'"' => {
      let can_open = delim_run_can_open(
        self.text,
        start,
        ix,
        1,
        mode,
        self.options,
      )
      let can_close = delim_run_can_close(
        self.text,
        start,
        ix,
        1,
        mode,
        self.options,
      )

      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + 1,
          body: MaybeSmartQuote(byte, can_open, can_close),
        }),
      )
      state.begin_text = ix + 1

      (ParseLineAction::Continue(0), state)
    }
    b'\x00' => {
      // U+0000 must be replaced with U+FFFD
      self.tree.append_text(state.begin_text, ix, state.backslash_escaped)
      state.backslash_escaped = false
      ignore(
        self.tree.append(Item::{
          start: ix,
          end: ix + 1,
          body: SynthesizeChar('\u{fffd}'),
        }),
      )
      state.begin_text = ix + 1
      (ParseLineAction::Continue(0), state)
    }
    _ => (ParseLineAction::Continue(0), state)
  }
}
