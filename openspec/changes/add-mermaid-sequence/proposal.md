# Proposal: add-mermaid-sequence

## Why

diagrams.mbt has no diagram format yet. Mermaid sequence diagrams are the first
format that the owner needs. People write them by hand, and later changes will
make them from Smithy models and OpenRPC documents. The output goes into web
pages, slide decks and Markdown documents. It must look as good as the diagrams
of the archify tool, and it must be correct and easy to read.

This change adds the first diagram kind, its first format and its first
renderer. It also sets the structure that the other formats will use.

## What changes

- Add a format-independent `Sequence` model to `moonrockz/diagrams`. Mermaid,
  PlantUML and Smithy transcripts will all produce this one model.
- Add links. A participant or a message can link to the item that it
  represents, for example the Smithy shape `example.weather#GetForecast`. The
  model can also hold render properties, such as a participant kind and a
  sublabel. Later adapters fill these properties from the linked item.
- Add a `Renderer` trait. A renderer turns a diagram model into output. Later
  renderers, such as an animated one, use the same trait.
- Add the new module `moonrockz/diagrams-mermaid`. It has a lossless CST, a
  parser with error recovery, a typed AST, a printer and a conversion to the
  `Sequence` model, for the complete sequence-diagram grammar of Mermaid 12.2.0.
- Add the new module `moonrockz/diagrams-svg`. It has a sequence layout and an
  SVG renderer with the visual style of archify. The SVG is one standalone file.
  It has dark and light themes that follow the viewer, and a fixed-colour mode
  for slide tools.
- Make legibility a tested property: no overlaps, labels fit, a minimum text
  size and a minimum text contrast in each theme.
- Add an unpublished `tests` module with a frozen corpus of Mermaid examples, and
  a gallery task that renders the corpus for visual review.

## Out of scope

- Animation and interactive output. A later change adds them through the
  `Renderer` trait.
- Resolution of Smithy links and Smithy transcripts. The change
  `add-smithy-sequence` adds them.
- Resolution of OpenRPC links. The change `add-openrpc-sequence` adds it.
- Other Mermaid diagram kinds, such as flowcharts, and other formats, such as
  PlantUML, Graphviz DOT and Draw.io.
- PNG, PDF and other raster or print output.
- Embedded font data in the SVG.
- Mermaid's own themes and its `%%{init}%%` theme variables. The parser keeps
  them in the CST and the AST, but the renderer does not use them.
- A change to the docs site renderer. The site keeps `bobzhang/beautiful_mermaid`.
- Publication. The new modules are publishable, but a release needs its own
  owner-approved pull request.

## Capabilities

### New capabilities

- `sequence-model`: the format-independent sequence model, its links and its
  render properties.
- `mermaid-sequence`: reading, checking, printing and converting Mermaid
  sequence diagrams.
- `sequence-svg-rendering`: the renderer contract, the sequence layout and the
  SVG output with its themes and legibility rules.

### Modified capabilities

None.

## Impact

- New modules `pkgs/diagrams-mermaid` and `pkgs/diagrams-svg`, and the
  unpublished module `tests`. All are registered in `moon.work` and use the root
  version.
- New packages in `pkgs/diagrams` for the sequence model and the renderer trait.
- New dependency for `diagrams-svg`: `moonbit-community/metrics` for text
  widths. The `diagrams` and `diagrams-mermaid` modules have no new third-party
  dependency.
- `scripts/publish.mbtx` lists the new public modules in dependency order. The
  release workflow publishes them only after an owner-approved release.
- New mise task for the gallery. `mise run check` runs the new tests on wasm,
  wasm-gc, js and native.
- `CONTEXT.md` gets the terms "diagram kind", "link" and "render properties".
  `docs/design/overview.md` describes one model for each diagram kind.
