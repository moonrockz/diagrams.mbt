# Changelog

## Unreleased

### Added

- Native Mermaid 12.2.0 flowchart/graph reading, lossless source trees, typed ASTs,
  canonical printing and independent upstream compatibility fixtures.
- PlantUML 1.2026.9 modern and legacy activity diagrams with typed branches,
  loops, forks, merges, lanes, partitions, notes and directional hints.
- Immutable shared flowchart values, bounded validation, themed standalone SVG,
  public geometry checks, finite motion plans, route/reachability exploration,
  offline players and canonical SVG export.
- Source, theme and player gallery examples, portable corpus rendering gates,
  independent source/canonical reference checks and fresh consumer checks.

### Changed

- **Breaking:** exhaustive matches on diagram, Mermaid dispatch, PlantUML
  document/kind, animation and SVG scene enums must handle flowcharts and activity
  documents. Existing entry points retain their contracts.
- The shared offline player supports flowchart visits and direction-aware routes.
  Static SVG output for existing diagram kinds remains unchanged.

## 0.2.0 - 2026-10-25

BPMN documents, diagrams and playback, plus native Mermaid swimlanes.

### Added

- `moonrockz/bpmn`: an independent portable BPMN XML reader and writer, with
  lossless source reproduction, structural validation, reference resolution,
  containment traversal and graph queries. It retains diagram interchange and
  vendor extensions and imports only MoonBit core.
- `moonrockz/diagrams-bpmn`: process and collaboration views, supplied diagram
  interchange geometry, and bounded automatic layout and routing.
- Pure motion plans and bounded structural exploration for sequence, BPMN and
  swimlane diagrams, including explicit concurrent scenarios and route choices.
- `moonrockz/diagrams-animated`: standalone offline HTML playback with seeking,
  speed controls, keyboard navigation, reduced motion and canonical SVG export.
- Native Mermaid 12.2.0 `swimlane-beta` reading, a lossless CST, typed AST,
  canonical printing and immutable swimlane models. SVG rendering supports all
  flow directions, nested and collapsed responsibility groups, unowned nodes,
  vector shapes and distinct parallel connections. Playback supports reverse
  routes and individual connection selection.
- BPMN and swimlane module guides, source examples, dark/light SVG review
  galleries and offline players. The docs site renders native swimlane fences.
- Shared OpenSpec workflows for Codex, Claude, Grok, Cursor, Muse and Copilot.

### Changed

- **Breaking:** exhaustive matches on public diagram, animation, motion and SVG
  scene enums must handle the new BPMN, swimlane and orientation variants.
  Existing sequence-specific Mermaid entry points remain available.
- All six public modules use the shared version `0.2.0`.

### Fixed

- Multi-kind Mermaid dispatch preserves headers after inline directives and on
  the closing line of multiline directives.
- Self-loops of hidden descendants stay hidden when their group or lane is
  collapsed. Visible self-loops and boundary handoffs remain available.

### Scope

- BPMN choreography and conversation data are retained; their rendering is
  deferred. Playback illustrates drawn structure and explicit scenarios; it
  does not execute BPMN processes or simulate tokens.
- Swimlane image/icon assets and unknown shapes produce explicit rendering
  errors. Rendering does not fetch author resources or execute author content.

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
