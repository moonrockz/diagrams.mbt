# Tasks

Create one epic and one story per numbered group after maintainer approval.
Replace each pending `Bead:` value with its story ID and add the dependencies
listed here. Keep all tasks unchecked until implementation is verified.

Each group runs `mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict` before its PR. Commit generated
interfaces with its API changes. Follow `CONTRIBUTING.md` for tracker state.

## 1. Qualify references and render both thin paths

Bead: diagrams-4qv.1

Depends on: none

- [x] 1.1 Freeze Mermaid 12.2.0 grammar/docs and the exact plugin 1.0.1/core 3.47.9 reference lock, with source commits, licences and digests; verify repeatable independent fixture extraction for one nested call and one architecture connection.
- [x] 1.2 Inventory the complete pinned annotator registry and provider asset terms; deliver a key/alias/source/licence manifest and prove UML, cloud and technology vectors can be normalized into standalone output without external references.
- [x] 1.3 Add the minimal typed syntax, model additions and dispatch for `zenuml` with one `@Actor` and one async message; verify lossless source, canonical print, conversion and SVG through the public convenience API on all four targets.
- [x] 1.4 Add the minimal architecture model, syntax, dispatch and SVG path for two services and one port-specific edge; verify the same public source-to-SVG path, fixed themes and a deterministic four-target snapshot.
- [x] 1.5 Document the thin-path limits and public enum migration in the module guides; verify examples compile and old sequence/BPMN/swimlane static snapshots remain unchanged in the required group checks.

## 2. Render the complete annotator catalog

Bead: diagrams-4qv.2

Depends on: 1

- [x] 2.1 Complete immutable namespaced references, participant icon defaults and render-property preservation in `pkgs/diagrams`; verify independent icon/kind values and unchanged existing constructor examples.
- [x] 2.2 Add the normalized vector catalog and provenance/attribution records under `pkgs/diagrams-svg`; verify every pinned registry key and alias resolves to its mapped asset and all emitted vector forms satisfy standalone SVG restrictions.
- [x] 2.3 Add used-symbol collection, deduplicated definitions and ID-prefix isolation; verify repeated symbols, separate inline copies, unknown-name warnings and bounded output without network or font dependencies.
- [x] 2.4 Integrate measured symbols with sequence labels, aliases, sublabels, creation rows and lifelines; verify per-key SVG coverage plus dark/light legibility and representative browser snapshots for UML, AWS, Azure, Google Cloud and technology symbols.
- [x] 2.5 Document annotator coverage, unknown-name behavior and asset attribution with a rendered contact sheet in the gallery; verify gallery links, artifact/module sizes and the required group checks.

## 3. Read and print the ZenUML profile

Bead: diagrams-4qv.3

Depends on: 1

- [x] 3.1 Complete stateful bounded ZenUML CST/AST reading for the declared syntax profile, including aliases and all annotators; verify every frozen documentation input, attached comments, CRLF and UTF-16 spans against fixtures.
- [x] 3.2 Add safe recovery for malformed statements, missing braces and unsupported extensions; verify later valid statements survive and reproduction remains exact without stack overflow or successful output after limit failures.
- [x] 3.3 Complete canonical printing from typed fields, including AST edits and expressions; verify parse/print equivalence, stable second prints and upstream acceptance of canonical corpus output.
- [x] 3.4 Finish per-kind limit options and diagnostic inventories without changing legacy signatures; document the profile and codes in the Mermaid module guide and verify consumer examples and the required group checks.

## 4. Convert and render complete ZenUML interactions

Bead: diagrams-4qv.4

Depends on: 2, 3

- [x] 4.1 Implement explicit call-stack conversion for implicit/explicit starters, sync/async calls, creation, typed/untyped assignments and each return form; verify participants, occurrence order, activation balance and target diagnostics against independent reference fixtures.
- [x] 4.2 Convert nested loops, alternatives, opt/par and attached comments; verify all documented spellings, nesting and comment placement through model assertions and rendered corpus snapshots on all four targets.
- [x] 4.3 Add typed try frames and plain/try/catch/finally section roles with compatible defaults; implement static painting and verify nested multi-catch/finally layouts and unchanged legacy sequence snapshots.
- [x] 4.4 Complete source annotator-to-icon mapping, alias/case rules and warnings; verify source-to-SVG for every frozen key without a known-key fallback, plus unknown annotator text and long-label cases.
- [x] 4.5 Add a ZenUML guide and gallery interactions covering nested calls, creation, returns, exceptions and symbol families; verify compiled examples, gallery output, legibility and the required group checks.

## 5. Read and validate complete architecture diagrams

Bead: diagrams-4qv.5

Depends on: 1

- [x] 5.1 Complete immutable groups, services, junctions, labelled connections, endpoint sides/group attachments and ordered alignments; verify mutation isolation, parallel IDs, invalid models and bounded ownership-cycle checks.
- [x] 5.2 Complete lossless CST/AST reading for every frozen architecture grammar production, imported terminal and metadata form; verify documentation/grammar corpus, malformed recovery and Unicode source positions.
- [x] 5.3 Implement canonical printing and reference-compatible semantic conversion, including duplicate IDs, declaration/reference rules, alignment eligibility and group endpoints; verify independent semantic fixtures and upstream acceptance after canonical printing.
- [x] 5.4 Complete architecture dispatch, per-kind limits, metadata warnings and no-output-on-error handling; document the APIs and diagram enum migration and verify public examples and the required group checks.

## 6. Lay out and paint complete architecture diagrams

Bead: diagrams-4qv.6

Depends on: 2, 5

- [x] 6.1 Implement deterministic measured placement for nested groups, disconnected elements and ordered cross-group row/column constraints; verify axis/order/containment assertions and distinct conflict/budget diagnostics.
- [x] 6.2 Implement bounded orthogonal routing for every port pair, group attachment, parallel edge, cycle and self-connection; verify endpoint geometry, labels, markers and routing-limit failures without successful partial SVG.
- [x] 6.3 Paint group/service symbols, five built-in icons, literal icon text, junctions, unknown fallbacks and accessibility fields; verify fixed/adaptive output, escaped hostile labels, definition isolation and identical four-target snapshots.
- [x] 6.4 Add the public legibility checker and dense/long-label fixtures; verify supported corpus output in both themes and that constructed overlap, overflow, small-text, endpoint and contrast errors are detected.
- [x] 6.5 Add architecture guides and gallery examples for nested groups, junctions, grids and group-boundary routes; verify links, browser theme behavior, unchanged older diagram snapshots and the required group checks.

## 7. Integrate offline playback for both additions

Bead: diagrams-4qv.7

Depends on: 4, 6

- [x] 7.1 Extend sequence frame projection and explicit scenarios for try/catch/finally while retaining symbols; verify nested occurrences, selected sections and no inferred exception outcomes in plan/model tests.
- [x] 7.2 Add architecture catalogs, binding cases and actual-path occurrences with service/junction identity and distinct parallel edges; verify group-boundary paths and forward/reverse motion agree with rendered geometry.
- [x] 7.3 Extend architecture route/reachability queries for headed, bidirectional and opt-in unheaded edges; verify cycles, junctions, bounds, reverse traversal and that alignment/containment create no routes.
- [x] 7.4 Add annotated ZenUML and architecture HTML fixtures to offline browser qualification; verify controls, keyboard use, reduced motion, visibility pause, still startup, safe labels, symbols and canonical SVG download during playback.
- [x] 7.5 Document playback semantics and new animation enum cases and add players to the gallery; verify compiled examples, deterministic HTML snapshots, all existing player contracts and the required group checks.

## 8. Qualify the integrated library and documentation

Bead: diagrams-4qv.8

Depends on: 7

- [x] 8.1 Verify the complete frozen corpus and asset manifest through their MoonBit mise tasks; confirm provenance/digest checks and generated fixture embeddings pass without a runtime JavaScript dependency.
- [x] 8.2 Run `mise run gallery -- --qualify`, `mise run test:svg` and `mise run test:animation`; verify source, static output, symbols, offline players and downloads across all diagram kinds.
- [x] 8.3 Run `mise run build:site`, `mise run check:site` and `mise run test:site`; verify the new guide/gallery links and integrated examples, then run the required group checks and review generated public interfaces.

## Workflow follow-up

- In the last task group's PR, archive this change with `mise exec -- openspec archive add-mermaid-zenuml-and-architecture --yes`, update moved links and run strict validation, formatting and checks as required by `CONTRIBUTING.md`.
- After each PR merges, close its completed stories with the PR and merge SHA. After all stories merge, point the epic to the archive, close it and run `bd dolt pull` followed by `bd dolt push`.
