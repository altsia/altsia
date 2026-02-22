# Kodama Design Notes

This file records package-level rules that should stay stable unless explicitly changed.

## Metadata

- One document has at most one top-level `(metadata ...)` app.
- `extract_raw_metadata_from_terms(...)` stops at the first metadata app and does not merge multiple metadata apps.
- Metadata is represented as `RawMetadata`:
  - `preset`: dedicated fields for known keys (`title`, `page-title`, `taxon`)
  - `custom`: all non-preset named args
- Preset/custom split is centralized in `metadata_build_from_named_map(...)` and reused by:
  - `extract_raw_metadata_from_terms(...)`
  - `extract_raw_metadata_from_metadata_args(...)`

## Slug

- Slug is auto-detected from `doc_id`.
- User-provided metadata `:slug` is not used as the document slug.
- `slug` remains a reserved preset key.

## Ref Rendering (Forester)

- `ref` is rewritten into local-link HTML shape (`span.link.local > a`).
- Anchor content is:
  - explicit ref text if provided, else
  - target document title term
- Anchor `title` attribute is target `title_with_slug` (`"<title text> [<slug>]"`).
- Anchor `href` keeps authored local target form for preview flow; deploy-time URL shaping is controlled by deploy options.

## Local Link Resolution

- Document id is workspace path (`doc_workspace_path`).
- Relative local links (for example `./b.alt`, `../b.alt`) are resolved against current document id to workspace-absolute candidate paths for metadata/document lookup.
