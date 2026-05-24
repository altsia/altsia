# Changelog

All notable changes to the "altsia-vscode" extension are documented in this file.

## 0.1.3 - 2026-02-16

### Added

- Added command palette action `Altsia: Normalize Document` (`altsia.normalize`) to run full-document normalize.
- Added setting `altsia.normalize.maxWidth` (default `80`, minimum `20`) for normalize width control.
- Added command palette action `Altsia: Set Normalize Max Width` (`altsia.normalize.maxWidth.set`) with preset and custom input.
- Added selection formatting support via `altsia_normalize_range`, so VS Code `Format Selection` works for `.alt` files.
