# Tasks

The owner authorized implementation of this plan on 2026-10-24.
Epic: diagrams-u42. Each numbered group has one story, with the dependencies stated
below. No implementation bead is closed before its PR merges.

Each group includes its own tests and documentation. Before its PR, run
`mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict`. Run browser qualification when
the group changes rendered artifacts or playback. Use the pinned toolchain for
nested commands; `MISE_ACTIVATE_AGGRESSIVE=1` avoids a local older MoonBit taking
precedence on PATH.

## 1. Prove one BPMN document through static and animated output

Bead: diagrams-u42.1.

- [x] 1.1 Create `pkgs/bpmn`, `pkgs/diagrams-bpmn` and `pkgs/diagrams-animated` with the root version and workspace membership; verify workspace/version validation and a reader-only consumer dependency graph.
- [x] 1.2 Freeze the five normative OMG schemas and a licensed minimal start-task-end fixture with complete DI, source URLs and SHA-256 digests; verify all digests with an unpublished acceptance test.
- [x] 1.3 Read that fixture to a lossless CST and immutable minimal typed document, write it, and walk its task; verify source reproduction, read-write-read equality and traversal order on all four targets.
- [x] 1.4 Convert the fixture to `Diagram::Bpmn` and render static SVG plus an HTML artifact that can play one flow highlight; verify snapshots, the renderer result/media types and a browser smoke check of play/pause.
- [x] 1.5 Add tested module examples and document the current limited coverage and enum compatibility change; verify the examples and the existing sequence snapshots on all four targets.

## 2. Complete lossless namespace-aware XML reading

Bead: diagrams-u42.2.
Depends on: group 1.

- [x] 2.1 Complete XML tokens and CST nodes for namespaces, attributes, comments, processing instructions, CDATA, mixed text and character references; verify reproduction and source partition laws for valid and malformed fixtures.
- [x] 2.2 Add namespace scope resolution, duplicate expanded-attribute checks and recovery at tag boundaries; verify namespace-alias equality, undeclared prefixes, mismatched tags and multiple findings in one source.
- [x] 2.3 Add UTF-16 source maps, stable diagnostic codes, explicit limits and prohibited DTD/entity handling; verify CRLF/non-BMP locations, each limit boundary and zero resource access.
- [x] 2.4 Document reading stages, limits, encoding and every XML diagnostic; verify runnable examples and agreement between the documented and exported code inventory.

## 3. Add schema-derived document foundations and canonical writing

Bead: diagrams-u42.3.
Depends on: group 2.

- [x] 3.1 Add the pinned-input schema inventory/generation MoonBit task and mise entry points; verify deterministic regeneration, schema digests and the generated element/attribute coverage manifest.
- [x] 3.2 Add immutable document/root/base values, typed scalar/enum/reference fields, exact DI numbers, absence tracking and ordered containment; verify constructor immutability, exact values and no inserted defaults.
- [x] 3.3 Implement canonical and pretty writers with deterministic namespace/attribute policies and iterative bounds checks; verify read-write-read equality, stable canonical bytes, forbidden-text rejection and mixed-content preservation on all four targets.
- [x] 3.4 Document construction, equality, source reproduction and canonical writing as separate APIs; verify their tested examples and negative namespace-binding cases.

## 4. Complete process and collaboration document types

Bead: diagrams-u42.4.
Depends on: group 3.

- [x] 4.1 Complete process, activity, subprocess, call, loop and multi-instance document fields; verify schema-inventory coverage and typed read/construct/write fixtures for each family.
- [x] 4.2 Complete events/event definitions, gateways and sequence-flow document fields; verify boundary attachment, expressions and catch/throw variants without executing their content.
- [x] 4.3 Complete collaborations, participants, nested lanes, message/data flows, artifacts, resources and shared definitions; verify references, child order and document round trips for each family.
- [x] 4.4 Add a pinned test-only bpmn-moddle reference fixture task and record its version and normalizations; verify core identities, containment, references and DI against the reference, and add tested process/collaboration examples.

## 5. Complete choreography, conversation, DI and extension documents

Bead: diagrams-u42.5.
Depends on: group 4.

- [x] 5.1 Complete choreography task/sub-choreography/call values and conversation nodes/links/associations; verify typed inspection, construction and document round trips while rendering remains explicitly unsupported.
- [x] 5.2 Complete BPMNDI, DI and DC shapes, labels, planes, waypoints and display fields; verify multi-plane documents and exact decimal values against the reference fixtures.
- [x] 5.3 Preserve foreign attributes/elements, mixed content and opaque QName-sensitive bindings, and diagnose unknown standard elements; verify prefix shadowing, vendor round trips and no silent standard-type omissions in the coverage manifest.
- [x] 5.4 Add independent-module examples for choreography, conversation, DI and extensions; verify all examples and schema inventory completeness on all four targets.

## 6. Validate structure and resolve explicit document references

Bead: diagrams-u42.6.
Depends on: group 5.

- [x] 6.1 Add per-document ID indexes and typed structural/containment validation; verify duplicate IDs, absent required fields, incorrect target kinds, boundary attachments and illegal cross-scope sequence flows.
- [x] 6.2 Resolve QName and imported-document references against an explicit resource set; verify namespace collisions, ambiguous targets, unresolved imports and no filesystem/network fallback.
- [x] 6.3 Keep syntax, structure and reference finding stages distinct, with source-backed and constructed locations; verify unaffected valid documents remain inspectable and unrelated unresolved imports do not block a selected self-contained view.
- [x] 6.4 Document validator coverage, codes and reference-resource inputs; verify runnable valid/invalid examples and the diagnostic inventory.

## 7. Complete document traversal and bounded graph queries

Bead: diagrams-u42.7.
Depends on: group 6.

- [x] 7.1 Add read-only node fields/children/paths and revision-bound handles across every document family and preserved XML; verify source order, optional locations and rejection of handles from another revision.
- [x] 7.2 Implement walk/fold/reduce/pruned reduction, typed visitors, pull/push events and cursor navigation using per-call stacks; verify normalized event equality, pruning/stop laws, reentrant walks and 10,000-level constructed documents.
- [x] 7.3 Add edge-kind/direction selection, bounded reachability and shortest directed routes; verify cycles, deterministic equal-length ties, disconnected targets, invalid endpoints and limit results distinct from unreachable.
- [x] 7.4 Document each traversal style and the containment/reference distinction; verify examples produce the same counts, identities and event order on all four targets.

## 8. Complete BPMN view conversion and the diagram model

Bead: diagrams-u42.8.
Depends on: groups 6 and 7.

- [x] 8.1 Complete the core BPMN diagram values for standard graphical kinds, ownership, labels, markers, flow endpoints, links/render properties and selected geometry; verify immutability and source-ID preservation without importing `bpmn` into `diagrams`.
- [x] 8.2 Add process/collaboration/plane selectors and unambiguous inference; verify multiple views, unsupported choreography/conversation, missing planes and invalid selected references return the specified diagnostics.
- [x] 8.3 Complete conversion for process/collaboration graphical elements and map diagnostics without losing spans; verify the coverage manifest has a conversion assertion for every graphical kind and no element is silently dropped.
- [x] 8.4 Document view selection, source/generated IDs and `Diagram` match migration; verify adapter examples and unchanged sequence behavior.

## 9. Render complete supplied BPMN diagram geometry

Bead: diagrams-u42.9.
Depends on: group 8.

- [x] 9.1 Add separate BPMN geometry and complete valid-DI consumption with a common viewport translation; verify every shape/label bound, edge waypoint and pool/lane/subprocess containment in the selected plane.
- [x] 9.2 Paint all standard process/collaboration symbols, event/task/gateway markers and connection kinds with the shared themes; verify per-symbol corpus snapshots and recognizable BPMN notation in dark/light adaptive and fixed output.
- [x] 9.3 Implement prefer/require/automatic geometry-policy dispatch and BPMN legibility findings; verify missing/partial/invalid DI, intentional attachments and broken imported geometry without silent rearrangement.
- [x] 9.4 Add standalone XML, escaping, accessibility, ID-prefix isolation and metadata checks; verify byte-identical SVG on all targets, a browser theme check and tested supplied-DI examples.

## 10. Lay out BPMN views without supplied geometry

Bead: diagrams-u42.10.
Depends on: group 9.

- [x] 10.1 Add deterministic scope decomposition, cycle condensation, ranking and measured lane/node placement; verify nested lanes/subprocesses, disconnected components, loops and long labels with focused geometry tests.
- [x] 10.2 Add endpoint ports and orthogonal routing for sequence/message/data flows, parallel edges, return paths and boundary events; verify actual endpoint identities, containment and distinct routes in the corpus.
- [x] 10.3 Enforce node/edge/search budgets and complete fallback layout under prefer-supplied; verify limit diagnostics, absence of mixed-coordinate results and no legibility findings for automatic corpus layouts.
- [x] 10.4 Document layout policies, supplied-geometry preservation and failure limits; verify generated/supplied examples, browser snapshots and the original sequence SVG snapshots.

## 11. Add pure motion plans and occurrence-aware exploration

Bead: diagrams-u42.11.
Depends on: groups 7 and 10.

- [x] 11.1 Add immutable motion steps, concurrent groups, source identity, finite scenarios and explicit-time sampling; verify deterministic samples, repeated occurrences, duration/size limits and plan mismatch rejection on all four targets.
- [x] 11.2 Project BPMN connections and sequence message occurrences/frames into exploration and motion values; verify self-messages, alt choices, bounded loop repetitions, parallel groups and no artificial participant cycles.
- [x] 11.3 Add diagram route/reachability selection with explicit connection kinds and visible-scope rules; verify agreement with document graph queries, shortest-route ties, cycles, collapsed scopes and distinct limit/unreachable results.
- [x] 11.4 Document illustrative flow, structural routes and explicit scenarios; verify examples keep gateway conditions/event descriptions without evaluating them or reporting execution outcomes.

## 12. Complete standalone HTML playback and browser qualification

Bead: diagrams-u42.12.
Depends on: group 11.

- [x] 12.1 Add render-scene bindings and reproducibly embedded browser assets without changing ordinary SVG output; verify display/canonical geometry equality and unchanged existing sequence bytes.
- [x] 12.2 Implement offline overlays, play/pause/restart/step/speed/seek and route/reach controls with safe data encoding; verify real path motion, keyboard operation, selected-route replacement and hostile label fixtures in a browser.
- [x] 12.3 Add still startup, reduced motion, visibility suspension, print output and byte-exact canonical SVG download; verify these behaviors for BPMN and sequence fixtures and that export preserves current viewer state.
- [x] 12.4 Add `mise run test:animation` through a MoonBit task and the existing Site build CI job, reusing locked Playwright/Chromium and current-commit stored snapshots; verify offline browser qualification without rebuilding the workspace/site, and that `ci-ok` requires this job's success.
- [x] 12.5 Document standalone HTML generation and browser requirements; verify runnable examples, four-target HTML byte identity and no network requests or console errors during qualification.

## 13. Review the integrated result and prepare the new modules

Bead: diagrams-u42.13.
Depends on: group 12.

- [x] 13.1 Extend the gallery with BPMN XML, selected static views and animated BPMN/sequence examples; verify its generation, light/dark output and all links from an existing-output rerun.
- [x] 13.2 Add the new modules to publication tooling in dependency order without publishing or changing the version; verify publication-script tests, root-version checks and a fresh reader-only `bpmn` consumer on all four targets.
- [x] 13.3 Update the glossary, architecture overview and site navigation to the tested module guides and static/animated examples; verify `mise run build:site`, `mise run check:site` and `mise run test:site`.
- [x] 13.4 Run the full acceptance, reference, gallery and animation qualification against the final candidate and obtain owner gallery review; record the results and approval in the PR.

## Workflow follow-up

- Archive this change in the PR that lands the last task group, after gallery
  review, and update links to the archived location.
- After each merge, close only its completed beads with the PR and merge SHA.
  Close the epic only after all child work has landed.
- Run `bd dolt pull` and `bd dolt push` and verify that the push succeeds.
- A GitHub release or mooncakes.io publication needs separate owner approval.
