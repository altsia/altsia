# kokic/cmark

A MoonBit port of the [pulldown-cmark](https://github.com/pulldown-cmark/pulldown-cmark) `0.13.1` **parser** (block + inline structure and the resulting event stream), behavior-complete apart from the deliberate deviations listed below.

The parser's behavior is validated against the full spec corpus — CommonMark, GitHub-flavored, and all pulldown-cmark extension specs — by comparing the event dump produced by this package against the reference Rust implementation, case by case, except where a deviation below applies.

## Scope

Implemented:

- Block parsing (headings, lists, blockquotes, code blocks, HTML blocks, tables, footnotes, definition lists, math, container extensions, metadata blocks, ...).
- Inline parsing (emphasis, links, images, autolinks, code spans, math spans, smart punctuation, wikilinks, strikethrough, highlight, superscript/subscript, ...).
- Event stream (`Event`/`Tag`/`TagEnd`) mirroring `pulldown-cmark::Event`.
- All extension flags via `Options`, bit-compatible with pulldown-cmark's `Options`.

Not implemented (out of scope, per the porting task):

- HTML rendering.
- Serde support.
- Broken-link / parser callbacks.

## Deliberate deviations from the CommonMark standard

These are intentional design choices, not bugs or unfinished work. Spec conformance and parity with the reference implementation are given up here on purpose.

- **Reference and footnote labels are case-sensitive.** `[Foo]: /url` defines only `[Foo]`, not `[foo]` or `[FOO]`; the same holds for GFM footnote labels. CommonMark and pulldown-cmark match labels after Unicode case folding, so the spec corpus will report differences for labels that differ only in case.

## Usage

```moonbit
let events = @cmark.parse(source, options)
```

Parse options are combined with `Options::insert`:

```moonbit
let options = @cmark.Options::empty()
options.insert(@cmark.enable_tables())
options.insert(@cmark.enable_footnotes())
let events = @cmark.parse(markdown, options)
```

## License

AGPL-3.0
