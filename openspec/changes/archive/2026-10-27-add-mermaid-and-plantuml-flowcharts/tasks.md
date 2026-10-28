# Tasks

Each numbered group is one beads story under epic `diagrams-bx7`. Groups 3, 4 and 5 depend on groups 1 and 2. Group 6 depends on groups
3, 4 and 5; group 7 depends on group 6; group 8 depends on group 7.
Run focused checks during each story, then `mise run format` and
`mise run check` before its pull request. Include changed generated interfaces.

## 1. Reference-backed source-to-player tracer

Bead: diagrams-bx7.1

- [x] 1.1 Prove independent PlantUML topology extraction for a branch, loop and parallel region in both applicable dialects, using pinned upstream internals or connection metadata; commit reproducible reference evidence that does not call the MoonBit converter.
- [x] 1.2 Freeze minimal Mermaid, modern activity and legacy activity tracer inputs, upstream versions, provenance, licenses and digests; verify acceptance and topology with the pinned reference tools and a repeatable check command.
- [x] 1.3 Add the minimal immutable flowchart model and renderer/dispatch variants, updating every exhaustive workspace match; verify a model-only consumer and an existing sequence-only consumer on all four targets.
- [x] 1.4 Read, reproduce, canonically print and convert a two-action tracer in Mermaid and both PlantUML dialects; verify round trips, distinct modern action occurrences and unsupported non-activity `@startuml` inputs with portable acceptance tests.
- [x] 1.5 Render the tracers as themed SVG and bind their real connection paths into the shared catalog, scene and offline player; verify route playback and canonical SVG download with network blocked.
- [x] 1.6 Add executable module-guide tracer examples and document the provisional feature coverage and enum additions; verify the examples and the existing static/player regression suites before landing the tracer.

## 2. Complete immutable flowchart values and validation

Bead: diagrams-bx7.2

- [x] 2.1 Complete ordered nodes, connections, notes, groups, explicit lanes, shape/label data, control roles, regions and source bindings; verify collection-copy behavior and separate equal-label/parallel occurrence identities.
- [x] 2.2 Add bounded validation for identity collisions, missing endpoints/note targets, ownership cycles, inconsistent regions and invalid limits; verify stable diagnostics and limit exhaustion on all four targets.
- [x] 2.3 Add deterministic generated-ID allocation and transformations that preserve source bindings and input values; verify authored-ID collisions, all directions and repeatable outputs in focused model tests.
- [x] 2.4 Document model construction, control roles and group-versus-lane ownership with checked consumer examples; verify model-only use has no parser, renderer, BPMN or UI dependency.

## 3. Complete Mermaid flowchart compatibility

Bead: diagrams-bx7.3

- [x] 3.1 Share header-aware grammar and metadata helpers with the swimlane path, keeping distinct flowchart AST/dispatch values and diagnostics; verify all accepted headers/directions and unchanged existing Mermaid consumer tests.
- [x] 3.2 Complete frozen documentation, grammar-production, shape and semantic coverage manifests; verify every production is accepted or has an independently recorded upstream refusal, with provenance and digest checks.
- [x] 3.3 Complete node redeclaration, implicit nodes, repeated/anonymous subgraphs, membership, local-direction and grouped-edge normalization; compare normalized flowchart values with pinned Mermaid database fixtures and verify no invented lanes.
- [x] 3.4 Complete typed canonical printing, recovery, source spans and metadata retention; verify AST-edit round trips, Unicode/CRLF positions, multiple errors, callbacks, unknown assets and all processing limits on four targets.
- [x] 3.5 Extend reference refresh/check and portable corpus embedding through MoonBit task scripts and mise; verify source and canonical output independently, and document supported semantics, presentation findings and unchanged swimlane behavior in checked guides.

## 4. Complete modern PlantUML activity support

Bead: diagrams-bx7.4

- [x] 4.1 Complete statement-aware modern dialect detection and typed actions, final forms, multiline text and presentation data; verify false positives in class/sequence blocks, comments and notes, plus existing four-kind block/body consumers.
- [x] 4.2 Complete if/elseif/else, switch/case, repeat/backward/break and while conversion with explicit continuation sets; compare ordered branches, loop returns/exits and terminated paths with independent upstream topology fixtures.
- [x] 4.3 Complete fork/join/merge, split, detach/kill, connectors and label/goto handling; verify distinct control roles, finite resolution, branch order, unresolved references and upstream refusals against the pinned corpus.
- [x] 4.4 Complete partitions, groups, explicit lanes, aliases, notes and typed canonical block/body printing; verify ownership, note attachments, AST edits and stable print/read/print results on all four targets.
- [x] 4.5 Freeze every modern documentation example and control-feature case with independent acceptance/topology evidence; verify malformed-input recovery, spans, execution/resource refusals and source/depth/work/output limits, and publish the checked modern compatibility guide.

## 5. Complete legacy PlantUML activity support

Bead: diagrams-bx7.5

- [x] 5.1 Complete legacy start/final forms, quoted actions, aliases, implicit previous activity and directional/labelled arrows; compare node reuse, endpoints, directions and source identity with pinned legacy fixtures.
- [x] 5.2 Complete nested conditionals, named synchronization bars, partitions and notes; verify typed roles, ordered regions, scope and note behavior against independently extracted topology.
- [x] 5.3 Complete legacy canonical printing, source recovery, span and dialect diagnostics; verify typed edits, Unicode/CRLF, ambiguous/mixed bodies, wrong markers, extra blocks and all processing limits.
- [x] 5.4 Freeze all legacy documentation examples and feature/refusal records, extending the existing PlantUML reference and embedding tasks; verify source and canonical output with the pinned reference, update checked guides and rerun existing regex/EBNF/JSON/YAML acceptance tests.

## 6. Complete flowchart SVG layout and scene coverage

Bead: diagrams-bx7.6

- [x] 6.1 Complete deterministic layout in all directions for nested/empty/collapsed groups, explicit lanes and disconnected nodes; verify containment, source-order ties, external-connection direction behavior and semantic/display endpoint separation.
- [x] 6.2 Complete cycles, self-loops, branches, joins, parallel routes, note attachment and edge-label placement; verify endpoint outlines and unintended intersection checks with focused geometry fixtures.
- [x] 6.3 Paint all supported pinned vector shapes and PlantUML control/final/note forms through shared primitives; verify shape/marker coverage, invisible constraints, asset refusal and reviewed light/dark/adaptive snapshots.
- [x] 6.4 Expose bounded geometry and legibility checking, with safe text/link metadata and ID prefixes; verify text size, contrast, hostile labels, inline isolation and node/edge/depth/work/dimension/output exhaustion.
- [x] 6.5 Complete scene bindings for visible nodes, notes, groups, lanes, regions and real paths; verify isolated node visits, hidden-descendant scope and all existing static SVG bytes, and document checked geometry/rendering examples.

## 7. Complete animation and structural exploration

Bead: diagrams-bx7.7

- [x] 7.1 Complete flowchart catalog roles and direction-aware route/reachability queries; verify reverse/bidirectional traversal, opt-in undirected edges, parallel selection, cycles, note/invisible exclusions and distinct invalid/outside-view/unreachable/exhausted results.
- [x] 7.2 Complete finite default illustrations and explicit scenarios with node visits, repeated loop edges and concurrent branch groups; verify pure sampled states, stable occurrence order, identity mismatches, durations and plan-size limits on all targets.
- [x] 7.3 Complete shared HTML serialization and runtime integration with structural labels and retained guard/join text; verify source escaping, no execution claims, offline controls, keyboard operation, reduced motion, hidden pages and print behavior in browser tests.
- [x] 7.4 Verify SVG download during visits, reverse routes and repeated/concurrent playback equals direct static output and preserves selection/progress; run the existing player suites and review deterministic shared-runtime HTML changes.
- [x] 7.5 Add checked playback/exploration guide examples for Mermaid and both activity dialects; verify fresh render/player consumers on four targets and the documented scenario and export commands.

## 8. Qualified gallery and integrated acceptance

Bead: diagrams-bx7.8

- [x] 8.1 Add at least one qualified Mermaid, modern PlantUML and legacy PlantUML gallery example, covering branch, loop, parallel and nested ownership across the set; verify exact source, themed SVG and offline player inputs through the checked gallery pipeline.
- [x] 8.2 Extend site family labels, qualified example counts, filters and version-aware links without changing existing stable routes/assets; verify gallery cards, source/download controls, no-script/narrow reading and both themes with site link and browser checks.
- [x] 8.3 Reconcile README, module/API guides, compatibility inventories, capability labels and changelog with the implemented profiles and exhaustive enum migration; verify checked examples and all documented task names against the final artifacts.
- [x] 8.4 Run both independent source/canonical reference checks, portable corpus/consumer suites, `mise run format`, `mise run check`, `mise run test:svg`, `mise run test:animation` and gallery qualification; verify no unresolved findings or unexplained existing static-byte changes.
- [x] 8.5 Run `mise run build:site`, `mise run check:site`, `mise run test:site` and `mise exec -- openspec validate --all --strict`; verify all acceptance requirements have coverage and every completed story task is ticked in its pull request.

## Workflow follow-up

- After approval, create or reuse one epic and one bead for each numbered group, record the IDs and dependencies, and claim each bead before implementation.
- The last task group's pull request archives this change and merges its deltas. Update the archived HTML asset links and run strict OpenSpec validation, formatting and the full check before merge.
- After each merge, close completed beads with the PR and merge SHA. Close the epic only when every child is closed, point it at the archive, and run `bd dolt pull` and `bd dolt push` successfully before deleting the branch.
- Ask the owner separately before any release or publication. Release only through the repository's approved workflow.
