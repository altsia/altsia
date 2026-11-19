# kokic/cmark

A MoonBit Markdown parser implementing
[Kodama Flavored CommonMark (KFC)](https://github.com/kodama-community/kodama/blob/main/vendor/KFC.md). See the linked
specification for syntax rules.

## Usage

```moonbit
let options = @cmark.Options::empty()
options.insert(@cmark.enable_tables())
options.insert(@cmark.enable_footnotes())
let events = @cmark.parse(markdown, options)
```

`parse` and `event_dump` raise `SyntaxError` for invalid emphasis. Streaming
parsers created with `new_parser` report errors during `next_event` or
`next_event_range`; consuming a prefix does not check the rest of the document.
Error ranges are half-open UTF-8 byte offsets into the original source, using
the same coordinate system as event ranges.
