# Proposal

## Why

Users need to explain patterns, grammars and structured data with the same
portable reading, rendering and exploration APIs as the existing diagrams.
PlantUML provides native regex, EBNF, JSON and YAML diagram formats for this work.

## What Changes

- Add `moonrockz/diagrams-plantuml` for the four native block types, lossless
  CSTs, typed ASTs, canonical writing, diagnostics, model conversion and SVG
  convenience calls. Pin compatibility to PlantUML `1.2026.9`.
- Add separate immutable regex and EBNF models, with shared railroad geometry.
  Preserve assertions, repetition bounds, rule references and exclusions as
  distinct concepts.
- Add an ordered structured-data model for JSON/YAML diagrams. Keep scalar
  types, number spelling, member order and occurrence identity. Apply the pinned
  PlantUML YAML scalar policy explicitly; this is not a general YAML processor.
- Add measured railroad and structured-data layout, legibility checks and
  standalone SVG using the existing adaptive and fixed dark/light themes.
- Extend the pure motion APIs, scene bindings and offline player. Animate actual
  railroad/connector paths and add typed node/row visits for data values without
  a drawn connector. Provide bounded structural route and hierarchy exploration.
- Add tested module examples, native source fixtures, compatibility/refusal
  manifests, SVG/player snapshots, a gallery and native PlantUML docs fences.
- **BREAKING:** extend public diagram, occurrence, motion and scene types.
  Document exhaustive-match and constructor migration while preserving existing
  entry points.

## Out of scope

- Other PlantUML diagram types, mixed UML diagrams, multi-block files and
  compatibility with every historical PlantUML version.
- Regex matching, input validation against a pattern, EBNF parsing or parser
  generation. Playback explains diagram structure; it does not prove acceptance.
- Full YAML schema resolution, alias expansion, merge-key processing, custom
  constructors or multi-document semantics. The native diagram profile governs
  whether such spelling is literal data or an unsupported construct.
- PlantUML preprocessing, macros, includes, remote resources, plugins and
  execution of author code. Retained presentation commands remain source data;
  library options control rendering.
- Upstream pixel equality, Java/Graphviz/server runtime dependencies, a UI
  package, a version bump or publication.

## Capabilities

### New Capabilities

- `plantuml-syntax`: four native envelopes and body readers, lossless CSTs,
  typed ASTs, canonical writing, diagnostics, conversion and pinned compatibility.
- `railroad-model`: immutable regex expressions and EBNF grammars, source
  identities, typed constraints and bounded validation.
- `structured-data-model`: ordered objects, arrays, scalar values, stable
  member/element identities and view highlights.
- `railroad-svg-rendering`: measured pattern/grammar geometry, readable
  connectors, safe labels, legibility and themed standalone SVG.
- `structured-data-svg-rendering`: nested data boxes and rows, collection
  connectors, safe highlights, legibility and themed standalone SVG.

### Modified Capabilities

- `diagram-animation`: railroad and data catalogs, first-class node visits,
  structural/hierarchy queries and the shared standalone playback contracts.

## Impact

- Add `pkgs/diagrams-plantuml` and register it in `moon.work`, version alignment,
  package validation, tested examples and dependency-ordered publication tooling.
  This change does not publish it.
- Add `regex`, `ebnf` and `data-tree` packages to `moonrockz/diagrams`. JSON and
  YAML are two source formats for one data-diagram kind. Regex and EBNF keep
  separate semantic models while sharing suitable rendering helpers.
- Extend `diagrams-svg`, `diagrams-animated`, the existing corpus/gallery/browser
  tasks and the unpublished docs site. Keep production logic pure on `wasm`,
  `wasm-gc`, `js` and `native`.
- Use a pinned PlantUML JAR/JDK only in a host-side reference task. Freeze source
  identities, digests, notices and normalized reference fixtures for portable
  tests. Do not copy the upstream renderer or run it in production.
- Preserve existing sequence, BPMN and swimlane static SVG bytes and semantics.
  Regenerate shared-runtime HTML snapshots deliberately when its schema changes.

## References

- [Regex](https://plantuml.com/regex), [EBNF](https://plantuml.com/ebnf),
  [JSON](https://plantuml.com/json) and [YAML](https://plantuml.com/yaml).
- [PlantUML 1.2026.9](https://github.com/plantuml/plantuml/releases/tag/v1.2026.9),
  commit `18d0aae311a4f1eb3723bb4b0ad939185e22f166`.
- [Pinned YAML conversion](https://github.com/plantuml/plantuml/blob/v1.2026.9/src/main/java/net/sourceforge/plantuml/yaml/parser/MonomorphToJson.java).
