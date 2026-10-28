# Tasks

Target one implementation pull request. Each numbered group is one story, not
one required PR. Dependencies: 2 follows 1; 3 and 4 follow 2; 5 follows 3 and 4;
6 follows 5; 7 follows 6. Tracking starts after approval.

## 1. Prove reference extraction and a complete state tracer

Bead: diagrams-d4d.1

- [x] 1.1 Extend the existing pinned Mermaid and PlantUML reference adapters for a minimal state lifecycle and a nested/concurrent fixture; verify independently extracted acceptance, hierarchy, pseudostate roles and transition endpoints, with provenance and digest records.
- [x] 1.2 Add a minimal immutable state model and public diagram/reader dispatch cases; verify one Mermaid and one explicit PlantUML state source can be read, printed, converted and validated on all four targets without changing existing dispatch fixtures.
- [x] 1.3 Carry both minimal sources through themed SVG, real-path scene bindings, a finite scenario, standalone HTML and canonical SVG download; verify one offline browser smoke test and four-target deterministic snapshots.
- [x] 1.4 Document the thin public path and source profile boundaries with executable examples; verify fresh model-only and reader/render consumers without new runtime dependencies, and provide MoonBit/mise tasks for the focused tracer checks.

## 2. Complete immutable state model and structural validation

Bead: diagrams-d4d.2

- [x] 2.1 Complete simple/composite states, root/nested/concurrent regions, separator orientation and source identity rules; verify copied inputs, immutable transformations, equal-label states, empty regions and deterministic IDs in model tests on all targets.
- [x] 2.2 Complete pseudostate and boundary roles, scoped initial/final/history references, ordered descriptions, transition labels and note attachments; verify shallow/deep history, entry/exit/pin/expansion roles, parallel/self transitions and internal descriptions without invented edges.
- [x] 2.3 Complete bounded validation for references, owners, cycles and options; verify invalid versus exhausted results with explicit size/depth/work limits and direction changes that preserve endpoints.
- [x] 2.4 Publish the model construction and validation guide and fresh model-only consumer; verify documented examples on all four targets and reject parser, renderer, host and UI dependencies in that consumer.

## 3. Complete native Mermaid state syntax and conversion

Bead: diagrams-d4d.3

- [x] 3.1 Freeze the pinned state documentation, grammar and semantic inputs with licenses, hashes and a complete feature/refusal inventory; verify the existing locked reference tools produce independently normalized expected values for all source fixtures.
- [x] 3.2 Complete both state headers, aliases, descriptions, implicit declarations, transitions, notes, composites, concurrent regions, pseudostates, directions and metadata; verify source losslessness, invalid-region recovery, CRLF/non-BMP spans, all processing limits and unchanged sequence/flowchart/swimlane/ZenUML/architecture dispatch.
- [x] 3.3 Complete source-compatible conversion for redeclarations, scoped identities, ownership, cross-composite acceptance/refusals and inert presentation; compare hierarchy, order, endpoints and roles with independent fixtures and verify no resource requests or execution.
- [x] 3.4 Complete typed canonical printing and format guide; verify AST edits, read/print equivalence, stable repeated printing, invalid values and limits, then qualify original and canonical source against pinned Mermaid and run dedicated-reader consumers on all four targets.

## 4. Complete native PlantUML state syntax and dispatch

Bead: diagrams-d4d.4

- [x] 4.1 Freeze PlantUML state documentation and relevant pinned sources with licenses, hashes and feature/refusal records; verify independent entity/ownership/role/link evidence for every supported construct and acceptance of original and canonical source.
- [x] 4.2 Separate UML envelope recognition from state/activity family selection and add explicit state-body reading; verify both activity dialects, all existing block/body kinds, wrong markers, extra blocks, mixed/ambiguous input, unsupported class/sequence input and misleading words inside quotes, comments or notes.
- [x] 4.3 Complete declarations, aliases/qualified names, descriptions, arrow hints, composites, both concurrent separators, pseudostates, history targets and boundary symbols; compare conversion with the pinned topology corpus, including cross-boundary child endpoints, implicit symbols, parallel transitions and self-loops.
- [x] 4.4 Complete lossless recovery and typed canonical block/body printing; verify edits, Unicode/CRLF spans, multiline notes, nesting, all limits, inert presentation and explicit include/preprocessing/asset refusals without I/O.
- [x] 4.5 Publish the PlantUML state compatibility guide and migration examples; verify dedicated-reader and existing consumer suites on all four targets, complete inventory coverage and independently qualified canonical output.

## 5. Complete state SVG layout, geometry and scenes

Bead: diagrams-d4d.5

- [x] 5.1 Complete deterministic layout for all directions, nested/empty composites, description compartments, concurrent separators and disconnected states; verify containment, readable text, source-order ties and supported local direction hints with focused geometry fixtures and checked guide examples.
- [x] 5.2 Complete cycles, self-loops, parallel transitions, note positioning and cross-boundary routes to real outlines/explicit points; verify readable labels, preserved endpoints and collapsed semantic/display endpoint separation with light/dark snapshots.
- [x] 5.3 Paint all supported state/pseudostate/boundary forms and integrate shared connector options; verify elbow/rounded/curved paths, default bridge/plain crossings, distributed attachments, marker corridors, true junction exclusions and final-path/mask inspection without changing existing static SVG bytes.
- [x] 5.4 Complete public geometry, bounded legibility checks and scene bindings; verify 11 px text/4.5:1 contrast, attachment/containment/collision checks, isolated visits, hostile labels, inline prefix isolation, adaptive themes and size/depth/work/dimension/output exhaustion.
- [x] 5.5 Publish checked rendering/geometry/connector examples and qualify stored state SVG; verify both native corpora pass geometry checks in fixed themes, fresh render consumers pass all targets and existing renderer/browser suites remain green.

## 6. Complete structural animation, queries and offline exports

Bead: diagrams-d4d.6

- [x] 6.1 Complete state catalog identity and bounded route/reachability integration; verify direction, reverse traversal, opt-in unheaded relations, parallel edge selection, cycles, hidden descendants and distinct invalid/outside-view/unreachable/exhausted results without ownership/history edges.
- [x] 6.2 Complete finite default illustrations and explicit repeated/concurrent scenarios with node visits; verify pure sample states, timing/order, source mismatch and plan limits on all targets, with no inferred guard result, history restoration or active configuration.
- [x] 6.3 Complete shared HTML serialization, inspection text and controls; verify offline operation, safe source encoding, keyboard/seek/speed/step behavior, reduced motion, page hiding and print using stored artifacts from both formats.
- [x] 6.4 Verify real-path forward/reverse motion, bridge/underpass selection and progress, and exact static SVG downloads during repeats/concurrency/visits; verify export preserves position, occurrence, selection and speed, then run all existing player browser suites with reviewed shared-runtime snapshots.
- [x] 6.5 Publish executable state/playback/query examples and fresh player consumers; verify four-target dependency boundaries and the documented MoonBit/mise artifact qualification commands.

## 7. Qualify gallery and integrated acceptance

Bead: diagrams-d4d.7

- [x] 7.1 Add and qualify three distinct sources per format with source, adaptive/light/dark SVG and offline players; verify lifecycle/self-loop, composite, choice/fork/join, concurrency and PlantUML history coverage, plus exact artifact bindings and no variant double-counting.
- [x] 7.2 Extend checked gallery generation, state family labels, filters and version-aware pages; verify source/preview/download/player controls, no-script 360-pixel browsing, both themes, stable old routes and unchanged prior source/SVG digests, and update the gallery guide with verified commands.
- [x] 7.3 Reconcile README, module/API docs, compatibility inventories and changelog with the final implementation; verify exhaustive-match migration guidance, no execution claims, complete requirement coverage and no undocumented new public cases or unsupported claims.
- [x] 7.4 Run both state reference checks, corpus validation, fresh consumers, stored SVG/player qualification and gallery qualification; verify all four target results, all existing format suites, `mise run format`, `mise run check`, `mise run test:svg` and `mise run test:animation` pass without unexplained snapshot changes.
- [x] 7.5 Run `mise run build:site`, `mise run check:site`, `mise run test:site` and `mise exec -- openspec validate --all --strict`; verify every requirement has acceptance evidence and completed story tasks are ticked in the implementation pull request.

## Workflow follow-up

- After approval, create or reuse one epic and one story per numbered group, record IDs/dependencies and claim a story before implementing it.
- Keep implementation in one PR unless a concrete constraint requires a split. The last group's PR archives this change and merges its deltas. Fix HTML asset links for archive depth and rerun strict validation, formatting and the full check before merge.
- After merge, close completed stories with the PR and merge SHA, close the epic only when all children are closed, then run `bd dolt pull` and `bd dolt push` successfully before deleting the branch and removing finished workspaces.
- Release and publication remain separate owner-authorized work through the repository release workflow.
