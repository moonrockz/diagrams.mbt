# Proposal

## Why

Automatic attachments follow a generic side-spreading rule that can place arrows
on the sloping edges of diamonds instead of their natural points. Gallery index
cards also show previews without the Source tab already available on detail pages.

## What Changes

- Select automatic attachment candidates from the real shape outline, considering
  line direction, shape size, marker clearance and other incident connections.
- Prefer diamond and choice points, usable straight edges on boxes, and natural
  perimeter approaches on rounded shapes. Distribute additional edges without
  turning independent connections into one apparent junction.
- Score source and target attachment pairs with the resulting route, rather than
  fixing generic side fractions before checking route quality.
- Retain explicit ports, side hints, supplied BPMN waypoints, source identities,
  minimum marker approaches, collision checks and deterministic work limits.
- Add Preview and Source tabs to gallery index cards and retain them on detail
  pages. Show the exact declared Mermaid, PlantUML, BPMN XML or other source text,
  with copy/download actions and a filename selector when an example has
  several source files.
- Preserve viewer state when switching tabs and keep no-script source access,
  themes, gallery filtering, fullscreen, pan/zoom and raster export working.
- Give local gallery examples the same inspection pattern where their original
  source is available; identify any example without declared source explicitly.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `connector-rendering`: Shape-aware automatic anchors and congestion handling.
- `diagram-gallery`: Source inspection within gallery index cards and local
  examples as well as existing detail pages.
- `state-svg-rendering`: Permit reviewed connector-only geometry updates while
  preserving state rendering semantics and public contracts.

## Out of Scope

- Diagram editing or changes to syntax, graph semantics, layout ownership or
  authored ports and supplied geometry.
- Converting a preview back into guessed source or adding ASCII diagram output.
- Broad changes to node placement, renderer themes, playback semantics or codecs.
- Rebuilding historical release artifacts.
- Adding a local copy of the shared Telescope gallery engine.

## Tracking

Approved for implementation. Epic diagrams-q4b tracks the five numbered stories.

## Impact

- Shared swimlane routing, outline geometry and checks used by swimlane,
  flowchart and state layouts; automatic BPMN routing and gateway attachments.
- Reviewed connector snapshots, public final path geometry, playback bindings,
  raster/GIF acceptance and qualified gallery previews.
- Shared Telescope gallery markup and tab controls through an upstream change
  and an approved published library/CLI release, then the diagrams.mbt consumer.
- Local gallery generation, source mapping, browser checks and documentation.

