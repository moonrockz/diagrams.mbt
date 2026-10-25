# Tasks

After design review, create one beads epic and one story per numbered group.
Replace each pending `Bead:` line with its story ID and add the dependencies
below. Each group lands its own tests and examples. Tick verified tasks in its
PR; close beads only after merge.

Before each PR run `mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict`. Use the pinned tools for nested
commands; `MISE_ACTIVATE_AGGRESSIVE=1` avoids an older local MoonBit on PATH.
Run `mise run test:svg` and `mise run test:animation` for rendering/runtime work.

## 1. Prove native source through a two-lane SVG and motion scene

Bead: diagrams-lkw.1.

- [x] 1.1 Freeze a minimal native `swimlane-beta LR` fixture and the upstream 12.2.0 source identities/licence/digests; add the initial immutable swimlane model and new diagram variant, and verify workspace/version checks and constructed-model immutability.
- [x] 1.2 Read that fixture to a lossless CST and typed AST, print it and convert two lanes with a cross-lane connection; verify reproduction, read-print-read equality and model ownership on all four targets.
- [x] 1.3 Lay out and paint the minimal view through the existing SVG renderer and add a minimal scene/catalog case; verify a stored SVG and one-edge animated HTML fixture with actual browser play/pause.
- [x] 1.4 Document the limited tracer coverage and public enum additions with tested module examples; verify existing sequence/BPMN static snapshots remain unchanged.

## 2. Complete the native grammar, AST and reference corpus

Bead: diagrams-lkw.2.
Depends on: group 1.

- [x] 2.1 Freeze the swimlane documentation examples, shared grammar and shape/statement coverage manifest; add a locked test-only `mermaid@12.2.0` reference task, and verify digests plus reproducible normalized parser/database fixtures.
- [x] 2.2 Complete lossless token/CST/AST support for subgraphs, local directions, node/shape data, all link forms, edge IDs, labels, class/style/click statements, accessibility, front matter and directives; verify every grammar/coverage fixture reads and reproduces without silently omitted statements.
- [x] 2.3 Add state-aware recovery, missing-end findings, UTF-16 locations and explicit input/nesting/expansion/work limits; verify two-errors, quoted-keyword, Unicode/CRLF, deep-group and edge-expansion boundary cases.
- [x] 2.4 Document syntax coverage and stable diagnostics, including parseable renderer-only metadata; verify runnable examples and agreement between documented and exported code inventories.

## 3. Complete semantic conversion, canonical printing and API dispatch

Bead: diagrams-lkw.3.
Depends on: group 2.

- [x] 3.1 Complete model values and conversion for implicit/redeclared nodes, repeated lanes, nested/collapsed groups, unowned nodes, shape aliases and distinct expanded/parallel connections; verify normalized models against the pinned upstream fixtures and constructed-model validation failures.
- [x] 3.2 Implement stable printing of every typed statement and retained metadata with ordered nesting and escaping; verify read-print-read equality and repeated canonical byte stability across the full corpus on all four targets.
- [x] 3.3 Add the new parsed-diagram union and read/print dispatch APIs while retaining existing sequence types/signatures; route `render_svg` through kind dispatch and verify unchanged sequence consumer examples plus unsupported-header/render-failure propagation without successful empty output.
- [x] 3.4 Document direction/marker normalization, metadata policy, source/generated IDs and API migration; verify examples for repeated lanes, grouped links and both supported Mermaid kinds.

## 4. Complete responsibility-band layout and routing

Bead: diagrams-lkw.4.
Depends on: group 3.

- [x] 4.1 Add separate swimlane geometry and measured lane/group/node placement with empty and unowned regions, local directions and collapsed visibility; verify source-order placement, nested ownership and header-space geometry assertions.
- [x] 4.2 Add cycle condensation, branch/join/disconnected ranking, all global direction transforms and return/self-edge channels; verify `TB`/`TD` equivalence, `BT`/`LR`/`RL`, stable lane order and no mirrored text.
- [x] 4.3 Add shape-outline ports, group/lane endpoints and bounded orthogonal routing for cross-lane, parallel and labelled edges; verify actual endpoints, header/label clearance, invisible constraints and explicit exhaustion results.
- [x] 4.4 Extract shared geometry helpers only where their inputs are neutral and preserve existing public BPMN wrappers; verify old sequence/BPMN SVG snapshots are unchanged and add tested swimlane layout/limits examples.

## 5. Paint the vector catalog and qualify static output

Bead: diagrams-lkw.5.
Depends on: group 4.

- [x] 5.1 Paint every pinned built-in vector shape, alias, supported label form, line style and endpoint marker; verify the coverage manifest, per-shape assertions and corpus snapshots without substituting unsupported assets.
- [x] 5.2 Apply shared adaptive/fixed themes, title/accessibility, escaped metadata and scoped inline IDs; verify dark/light browser rendering, safe text/metadata and independent inline copies.
- [x] 5.3 Add the public swimlane legibility checker and explicit renderer errors for asset/unknown shapes; verify broken geometry/contrast/attachment findings, no findings for the supported corpus and zero resource fetches.
- [x] 5.4 Extend existing SVG browser qualification with swimlane fixtures and tested rendering/metadata-policy examples; verify standalone XML, four-target static byte equality, actual outline/header clearance and retained old static snapshots.

## 6. Complete directed swimlane playback and path exploration

Bead: diagrams-lkw.6.
Depends on: group 5.

- [x] 6.1 Complete swimlane catalog/scene bindings with independent parallel-edge identities, visible group/lane endpoints and exclusion of invisible constraints; verify model/scene/plan identity matching and exact routed-path bindings.
- [x] 6.2 Add oriented route arcs, optional undirected edge selection and direction-aware motion steps while retaining existing forward steps; verify forward/reverse/bidirectional routes, headless opt-in behavior, cycles, bounds and finite repeated occurrences on all targets.
- [x] 6.3 Extend the existing embedded player for typed swimlane selection and reversed path interpolation; verify actual reverse motion, unchanged markers, route/reach controls, collapsed outside-view results and no paths inferred from lane membership.
- [x] 6.4 Qualify still startup, keyboard controls, reduced motion, visibility suspension, offline safety and canonical SVG export for swimlanes; verify old BPMN/sequence playback contracts, deliberately regenerated runtime-dependent HTML snapshots and unchanged static SVG bytes.
- [x] 6.5 Document structural direction, finite scenarios and unsupported execution/asset features; verify runnable animated examples and deterministic plan/HTML generation.

## 7. Review integrated examples and finish the change

Bead: diagrams-lkw.7.
Depends on: group 6.

- [x] 7.1 Extend the gallery/site examples with static and animated swimlanes, all directions and an approval/return-path example; verify repeatable example generation and gallery links through existing tasks.
- [x] 7.2 Update the glossary, architecture overview, module navigation and site guide to the tested APIs; verify `mise run build:site`, `mise run check:site` and `mise run test:site`.
- [x] 7.3 Run full corpus/reference, four-target, SVG and animation qualification on the final candidate using existing CI gates; verify current-commit snapshots and browser inputs agree without adding duplicate compilation or a new platform matrix.
- [ ] 7.4 Obtain owner gallery review and record the supported shape/metadata policy, compatibility notes and approval in the final PR; verify all story tasks are checked before archival.

## Workflow follow-up

- Archive the change in the PR that lands the last group and update its links.
- After each merge, close its completed beads with the PR and merge SHA. Close
  the epic only after all children close, then verify `bd dolt pull` and push.
- Publication or a version release requires separate owner approval.
