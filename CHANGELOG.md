# Changelog

## 0.1.0 - 2026-10-24

Initial workspace for diagrams.mbt. It shares the setup of the other moonrockz
projects, such as moonrockz/moon-lander.

### Added

- The `moonrockz/diagrams` library package.
- An immutable sequence model, link and render-property contracts, structured
  diagnostics and a common renderer trait.
- `moonrockz/diagrams-mermaid`: a lossless Mermaid 12.2.0 sequence reader,
  typed AST, canonical printer, semantic diagnostics and model conversion.
- `moonrockz/diagrams-svg`: complete sequence layout, legibility checks and
  standalone archify-style SVG with adaptive and fixed dark and light themes.
- A frozen corpus of 38 Mermaid examples, cross-target SVG snapshots, browser
  checks and a dark/light review gallery.
- Beads and OpenSpec integration for work tracking and specifications.
- A docs site on GitHub Pages, built with the shared moonrockz site tool.
- CI, release and site workflows.

### Fixed

- The workspace repository URL points to `moonrockz/diagrams.mbt`.
