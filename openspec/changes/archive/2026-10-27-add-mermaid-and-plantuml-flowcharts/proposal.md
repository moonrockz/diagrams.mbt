# Proposal

## Why

The library cannot yet read ordinary Mermaid flowcharts or PlantUML activity
diagrams. Add these formats with the same model, rendering, animation and
exploration support as the existing diagram families.

## What Changes

- Read Mermaid `flowchart` and `graph` source against the existing Mermaid
  12.2.0 baseline, including the shared grammar's header aliases.
- Read both modern and legacy PlantUML activity syntax inside `@startuml`
  blocks against the existing PlantUML 1.2026.9 baseline.
- Provide lossless source trees, typed ASTs, stable diagnostics, canonical
  printers and conversion to an immutable, format-independent flowchart model.
- Keep node, edge, branch, loop, parallel-region, note and group identities.
  Mermaid subgraphs remain groups. Explicit PlantUML lanes remain lanes.
- Render standalone SVG with shared themes, public geometry and legibility
  checks. Support the built-in vector symbols in the pinned profiles and report
  unsupported assets or presentation behavior explicitly.
- Provide motion plans, node visits, explicit scenarios, bounded route and
  reachability exploration, offline HTML playback and canonical SVG download.
- Add independently qualified compatibility corpora, module guides and checked
  static and animated gallery examples for both formats.
- **BREAKING**: add flowchart variants to public exhaustive enums, including
  the renderer diagram, Mermaid dispatch, and PlantUML document/kind values.
  Existing entry points and behavior for existing kinds retain their contracts.

### Out of Scope

Process execution, condition evaluation and fork synchronization simulation;
automatic translation between Mermaid and PlantUML source; other PlantUML UML
families; remote renderers, Java or upstream JavaScript in the runtime library;
external asset loading; exact upstream coordinates or theme reproduction; and
new application UI packages. Existing offline player and docs UI are reused.

## Capabilities

### New Capabilities

- `flowchart-model`: immutable flowchart values, typed control roles, ownership,
  stable identities and bounded validation.
- `mermaid-flowcharts`: native reading, source preservation, canonical printing,
  semantic conversion and pinned compatibility coverage.
- `plantuml-activity`: modern and legacy activity reading, printing, control-flow
  conversion and pinned compatibility coverage.
- `flowchart-svg-rendering`: deterministic geometry, vector painting, themes,
  legibility checks and scene bindings.

### Modified Capabilities

- `mermaid-swimlanes`: extend kind dispatch to flowcharts and remove their
  obsolete unsupported-header expectation while retaining swimlane semantics.
- `plantuml-syntax`: extend block/body dispatch and compatibility inventory to
  activity documents while retaining the four existing native block kinds.
- `diagram-animation`: add flowchart catalogs, structural queries, scenarios
  and shared offline playback with the existing accessibility/export contracts.
- `diagram-gallery`: add qualified Mermaid and modern/legacy PlantUML examples
  without changing existing example routes, assets or filters.

## Beads

Epic `diagrams-bx7` tracks this change. The eight task groups use stories
`diagrams-bx7.1` through `diagrams-bx7.8`, with their dependencies recorded.
Deliver the stories together in one pull request. Close them only after merge.

## Impact

Changes affect `pkgs/diagrams`, `pkgs/diagrams-mermaid`,
`pkgs/diagrams-plantuml`, `pkgs/diagrams-svg`, `pkgs/diagrams-animated`, the
unpublished acceptance suites, corpus and gallery scripts, module guides and
`apps/site` gallery inputs. Reuse existing geometry, shape, theme, motion and
player facilities where their semantics fit. Keep all domain processing pure
and bounded on wasm, wasm-gc, js and native. Upstream Mermaid and PlantUML
runtimes remain pinned test tools only. No new published module is required.
