# Proposal

## Why

The library cannot yet read or render state diagrams. Users need to describe
lifecycles with nested states and concurrent regions, then inspect and animate
them through the same portable APIs as the existing diagram families.

## What Changes

- Add native Mermaid `stateDiagram` and `stateDiagram-v2` reading, lossless
  source trees, typed canonical printing and model conversion.
- Add native PlantUML state diagrams in `@startuml` blocks, with explicit
  state/activity dispatch and raw state-body reading.
- Add an immutable state model with simple and composite states, ordered
  concurrent regions, transitions, descriptions, notes and typed pseudostates.
  Preserve source-specific scope and identity rules. Keep event, guard, action,
  entry, exit and history descriptions as data.
- Render standalone adaptive/light/dark SVG with public geometry, scene
  inspection, readable transition labels, configurable line styles and default
  crossing bridge hops under the accepted connector contract.
- Add finite illustrative animation, explicit repeated/concurrent scenarios,
  node visits, bounded route/reachability queries and offline HTML with the
  existing accessible controls and exact canonical SVG download.
- Add independently qualified syntax corpora, four-target consumer checks,
  guides and at least three distinct gallery sources for each input format.
- **BREAKING**: Add state cases to public diagram, reader and scene dispatch
  values. Document migration for exhaustive matches. Existing format behavior
  and static SVG bytes remain stable.

## Capabilities

### New Capabilities

- `state-model`: Immutable state hierarchy, regions, pseudostates, transitions,
  descriptive behavior text, identity and bounded validation.
- `mermaid-state-diagrams`: Native state grammar, source fidelity, typed
  printing, reference-compatible conversion and pinned qualification.
- `plantuml-state-diagrams`: Native state grammar and conversion, scoped
  history and boundary forms, canonical printing and pinned qualification.
- `state-svg-rendering`: Deterministic nested layout, symbols, transition
  geometry, scene bindings and standalone themed SVG.

### Modified Capabilities

- `plantuml-syntax`: Extend native block dispatch to state documents while
  retaining existing activity dialect selection and other block contracts.
- `diagram-animation`: Add state catalogs, structural queries, finite motion,
  shared offline playback and canonical export.
- `diagram-gallery`: Add qualified state examples, format labels, downloads,
  players and guides without changing existing routes.

## Out of scope

State-machine execution, event scheduling, guard evaluation, action execution,
automatic history restoration, inferred active configurations and UML conformance
checking are out of scope. No external renderer, JavaScript parser, Java,
Graphviz, resource fetch or UI framework becomes a library dependency. Source
styling remains retained data with explicit findings for unapplied behavior;
pixel matching upstream renderers, arbitrary embedded markup, preprocessing and
external assets are out of scope.

The owner approved implementation, merge and the next project release on
2026-10-28. Release 0.4.0 accompanies this change through the existing GitHub
Actions workflow. Publication from a workstation remains excluded.

## Beads

Approved and tracked by epic `diagrams-d4d` and stories `diagrams-d4d.1` through
`diagrams-d4d.7`. Each numbered task group is one story.

## Impact

Changes affect `pkgs/diagrams`, both native readers, `pkgs/diagrams-svg`,
`pkgs/diagrams-animated`, acceptance suites, MoonBit task scripts, guides and the
checked site/gallery pipeline. Keep the existing Mermaid 12.2.0 and PlantUML
1.2026.9 baselines. Upstream tools remain test-only. Plan one implementation PR
with the archive included; split only if a concrete integration constraint
requires it.
