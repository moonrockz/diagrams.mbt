# Proposal

## Why

Users need Mermaid diagrams that show which actor owns each process step and
where work moves between actors. Mermaid 12.2.0 already defines native
`swimlane-beta` syntax; diagrams.mbt should read that format and provide the same
static rendering and path exploration available for its existing diagram kinds.

## What Changes

- Add lossless Mermaid 12.2.0 swimlane reading, a typed AST, canonical printing
  and conversion in `moonrockz/diagrams-mermaid`. Use the native header and its
  shared flowchart grammar, including nodes, edges, nested subgraphs and metadata.
- Add an immutable, format-independent swimlane model with ordered lanes,
  nested groups, node shapes, connections, labels, direction and accessibility.
  Keep its meaning separate from BPMN execution and message semantics.
- Add deterministic lane layout and standalone SVG painting in
  `moonrockz/diagrams-svg`, including horizontal/vertical flow, reverse directions,
  long labels, cyclic flows and cross-lane handoffs.
- Extend the shared animation catalog, scene bindings and animated HTML renderer
  to swimlanes. Keep edge identities, direction and repeated occurrences, and
  support the existing playback, route, reachability and static-export controls.
- Preserve existing sequence-specific reading/printing APIs. Add a new
  diagram-dispatching read API and let the existing SVG convenience call handle
  both supported Mermaid headers.
- **BREAKING:** add swimlane variants to the public diagram and animation enums.
  Document migration for callers that match those enums exhaustively.

## Out of scope

- Ordinary `flowchart`/`graph` input as another supported diagram kind. The
  swimlane reader uses the shared grammar under `swimlane-beta` only.
- BPMN conversion, execution engines, condition evaluation or inferred business
  semantics from a lane, diamond or cross-lane edge.
- Fetching fonts, icons or images; running Mermaid callbacks; injecting author
  HTML/CSS; reproducing Mermaid's renderer-specific themes, layout engines or
  exact pixel placement. Preserve such source data and diagnose unsupported
  rendering features rather than silently substituting unrelated output.
- Image/icon asset rendering, two-axis phase grids, a UI package, a release or
  publication. Existing libraries remain pure across the four supported targets.

## Capabilities

### New Capabilities

- `mermaid-swimlanes`: native Mermaid syntax, CST, AST, diagnostics, canonical
  printing, conversion and multi-kind API dispatch.
- `swimlane-model`: immutable responsibility lanes, nested groups, shape and
  connection identity, direction and render metadata.
- `swimlane-svg-rendering`: deterministic lane geometry, shape painting,
  legibility and self-contained themed SVG.

### Modified Capabilities

- `diagram-animation`: add swimlane catalog/projection, route direction and
  playback scenarios while retaining all existing animation contracts.

## Impact

- Add packages inside the existing diagrams, diagrams-mermaid and diagrams-svg
  modules. Extend diagrams-animated and its embedded runtime only where the new
  model requires it. No new published module is necessary.
- Reuse text measurement, palettes, XML escaping and suitable geometry routines.
  Keep kind-specific layout and semantics separate; preserve existing BPMN and
  sequence APIs, static SVG bytes and playback behavior for unchanged inputs.
- Use pinned, portable `moonbit-community/yaml@0.0.8` events to bound metadata
  aliases and logical depth before `moonbitstack/moonyaml@0.1.1` resolves
  shape-data values. The core swimlane model has no parser dependency.
- Freeze upstream grammar, documentation examples and reference behavior at
  Mermaid 12.2.0 with source/licence/digest metadata. Use Mermaid itself only
  as a pinned test oracle, not a runtime dependency.
- Extend the gallery, module examples, site guide, four-target acceptance tests
  and existing browser qualification with swimlane fixtures.
