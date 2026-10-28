# Proposal

## Why

Short approach segments can put arrowheads too close to a bend. Plain line
crossings make unrelated connections look joined. The published gallery also
shows too few distinct examples of most supported diagram families.

## What Changes

- Reserve enough straight space at connection endpoints for the actual marker,
  stroke width and selected connector style. Spread multiple attachments across
  each usable side, and use clear top and bottom approaches in automatic routing
  when they reduce congestion. Preserve explicitly authored ports.
- Add typed renderer options for elbow, rounded-elbow and smooth curved lines.
  An omitted style keeps the diagram family's natural line style.
- Show owner-confirmed bridge hops by default where unrelated visible connections
  cross: a small rounded arch over the other line, with a clear underpass.
  Provide an explicit plain-crossing option. Keep real joins joined.
- Use one resolved path for SVG, inspection, legibility checks, static trace
  highlights and playback. Preserve crossing masks during highlighting.
- Preserve supplied BPMN paths by default. Allow explicit display styling without
  changing source waypoints. This is a proposed author decision for review.
- Add at least three distinct source examples to each of the ten published
  gallery families, for at least 30 additional examples and 45 cards in total.
  Include all three flowchart source forms. Show connector-style comparisons.
- **BREAKING** visual output change: default bridges and improved endpoint space
  change affected SVG and HTML snapshots. Existing source files, identities,
  public routes and workflow semantics remain stable. No dependency or release
  version change is part of this proposal.

## Capabilities

### New Capabilities

- `connector-rendering`: shared connector styles, endpoint clearance, crossing
  bridges, path geometry, limits and deterministic drawing.

### Modified Capabilities

- `sequence-svg-rendering`: connector options and reviewed visual compatibility.
- `bpmn-diagrams`: safe automatic endpoints and explicit styling of supplied paths.
- `swimlane-svg-rendering`: shared styles and revised visual compatibility.
- `flowchart-svg-rendering`: shared paths, legibility and revised visual compatibility.
- `architecture-svg-rendering`: shared styles with authored ports and revised visual compatibility.
- `railroad-svg-rendering`: styled connectors keep grammar joins and trace geometry.
- `structured-data-svg-rendering`: styled hierarchy connectors keep row identity.
- `diagram-animation`: playback and export use the resolved styled paths and masks.
- `diagram-gallery`: more distinct sources per family and qualified style examples.

## Out of Scope

New source languages, new diagram kinds, choreography or conversation rendering,
workflow execution, source-level style grammar extensions, external layout
services, a library UI package, publication and releases are out of scope.
This change does not rewrite supplied BPMN documents or redefine crossing lines
as graph edges. It does not add a whole historical SVG renderer for old bytes.

## Beads

Epic `diagrams-w16` tracks this change. Stories `diagrams-w16.1` through
`diagrams-w16.6` track the six task groups. Close stories only after their pull
request merges.

## Impact

The work affects `pkgs/diagrams-svg` routers, painters, public renderer options,
geometry checking and scene bindings; `pkgs/diagrams-animated` overlays; the
gallery acceptance suites; `scripts/gallery.mbtx`; `site/gallery.json`; selected
site assets; and guides. Reuse the existing four-target checks and offline
browser qualification. No upstream rendering dependency is needed.
