# notiz

A deterministic, strict Markdown parser in MoonBit, built on
[`talcparsec`](https://mooncakes.io/packages/kokic/talcparsec).

`notiz` is **not** a CommonMark-conformant parser. It is a deliberately strict
subset designed around a few principles:

## Strict semantics, not graceful degradation

Reserved characters are interpreted as syntax **only** when they form a
complete construct. Once a reserved prefix appears, the parser commits to
parsing that construct and **errors if it is not well-formed** — it does *not*
silently fall back to treating the input as plain text. Malformed use of a
reserved prefix is a hard error, not a fallback to text.

## Formatting markers are reserved, not punctuation

`*`, `_`, `` ` ``, `$`, `\` are **formatting markers**. A bare or unclosed
occurrence is a parse error: in formatted text such a character should be
written as inline code or escaped, not exposed as special-looking plain text.
Escape sequences (`\*`, `\_`, `` \` ``, `\$`, `\\`) produce a literal
character; escaping any other character is an error.

## Link syntax `[...](...)` is not supported

The `[]()` link syntax is not supported; `[text]` and `[text](url)` are kept as
plain text. `[` and `]` are only special as the footnote reference prefix
`[^`; a bare `[` or `]` is ordinary text. `!` is ordinary punctuation, so an
exclamation mark in prose is parsed as plain text.

## Determinism over backtracking

The grammar avoids backtracking: every construct starts with either a fixed
atomic prefix or a character unique to that construct. Alternatives have
disjoint first tokens, so each input has a single parse and there is no
exponential blow-up on adversarial input such as runs of unclosed brackets.
