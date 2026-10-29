# Changelog

## Unreleased

### Added

- Accessible Preview and Source tabs in gallery cards and the offline review
  gallery, with original syntax, source downloads and retained viewer state.

### Changed

- Automatic connectors prefer clear diamond and choice points, use measured
  outline spans and consider route congestion while preserving explicit ports,
  direction hints and supplied BPMN waypoints.

## 0.4.0 - 2026-10-28

### Added

- Native Mermaid 12.2.0 `stateDiagram` and `stateDiagram-v2`, and PlantUML
  1.2026.9 state blocks and explicit state bodies, with lossless source trees,
  UTF-16 diagnostics, editable typed ASTs and canonical printers.
- Immutable state models with composite and concurrent regions, scoped
  initial/final and history symbols, boundary roles, descriptions, notes and
  bounded structural validation.
- Standalone themed state SVG, public geometry and connector inspection,
  collapsed views, curves, bridges, finite scenarios, node visits and
  structural route/reachability queries in the shared offline player.
- Six distinct gallery sources with themed SVG, exact source downloads and
  offline players, plus model, source compatibility and playback guides.
- Independent pinned state topology corpora, portable acceptance tests and
  fresh model, dedicated-reader and player consumers across four targets.

### Changed

- Exhaustive matches must handle `Diagram::State`, Mermaid parsed/tree state
  cases, PlantUML `Kind::State` and `Document::State`, and state animation,
  graph, visit and SVG node binding cases.
- UML envelope dispatch distinguishes state and activity evidence and reports
  ambiguous input. Explicit body reading selects the intended family.
- All seven public modules use the shared version `0.4.0`.

### Scope

State playback illustrates authored structure and supplied scenarios. It does
not evaluate guards, run actions, restore history or execute state machines.

## 0.3.0 - 2026-10-28

Native PlantUML, Mermaid flowcharts, ZenUML and architecture diagrams, with
clearer connectors and an expanded gallery.

### Added

- `moonrockz/diagrams-plantuml`: native PlantUML 1.2026.9 regex, EBNF, JSON,
  YAML and modern/legacy activity readers, canonical printers and conversion.
  The published library needs no Java, Graphviz or rendering service.
- Regex and EBNF railroad models, ordered JSON/YAML data trees, themed SVG,
  structural exploration, node visits and offline players. Regex matching and
  grammar parsing evidence comes from an explicit external trace provider.
- Mermaid `zenuml` interactions with nested calls, returns, creation,
  try/catch/finally sections and the pinned 523-key participant symbol catalog.
- Mermaid `architecture-beta` groups, services, junctions, explicit ports,
  labelled connections, ordered alignments, SVG and structural playback.
- Native Mermaid 12.2.0 flowchart/graph reading, lossless source trees, typed ASTs,
  canonical printing and independent upstream compatibility fixtures.
- PlantUML 1.2026.9 modern and legacy activity diagrams with typed branches,
  loops, forks, merges, lanes, partitions, notes and directional hints.
- Immutable shared flowchart values, bounded validation, themed standalone SVG,
  public geometry checks, finite motion plans, route/reachability exploration,
  offline players and canonical SVG export.
- Source, theme and player gallery examples, portable corpus rendering gates,
  independent source/canonical reference checks and fresh consumer checks.
- Typed connector options for elbow, rounded-elbow and smooth curved paths,
  default rounded bridge hops at unrelated crossings, optional plain crossings,
  final path inspection and bounded geometry checks.
- Thirty additional distinct gallery sources across all ten diagram families,
  plus six connector comparison views, for 51 published gallery cards.
- A versioned documentation site built with Telescope, with source inspection,
  stable gallery detail routes, downloads and offline player links.

### Changed

- **Breaking:** exhaustive matches on diagram, Mermaid dispatch, PlantUML
  document/kind, sequence frame, animation and SVG scene enums must handle the
  added diagram, activity and exception variants.
- **Breaking visual change:** default crossing bridges and longer marker
  approaches intentionally change affected SVG and HTML output. Omitted line
  style keeps each diagram family's natural form. `Plain` disables bridges.
- Shared offline playback follows the final styled paths and underpass masks,
  including reverse routes, repeated occurrences and configured trace highlights.
  Static downloads equal direct rendering and preserve viewer state.
- Automatic graph routing reserves readable arrow approaches, spreads shared-side
  attachments and uses clear alternate sides for congested routes. Authored
  ports and direction hints retain their sides.
- All seven public modules use the shared version `0.3.0`.

### Scope

- Playback illustrates structure and caller-supplied scenarios. It does not
  execute workflows, evaluate branch conditions or simulate BPMN tokens.
- Complete supplied BPMN geometry stays unchanged by default. Display curves
  and bridges require explicit `style_supplied_bpmn=true`; source waypoints
  remain available and unchanged.
- Frozen source profiles, unsupported assets and preprocessing forms retain
  explicit diagnostics without fetching resources or running source content.

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
