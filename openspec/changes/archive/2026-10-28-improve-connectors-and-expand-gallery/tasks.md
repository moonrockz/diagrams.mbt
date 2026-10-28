# Tasks

Each numbered group is one story under epic `diagrams-w16`. The Bead lines
record their IDs and the tracker has the stated dependencies. Keep tasks unchecked until
their behavior is verified. The supplied-BPMN default is the proposed Call in
CON-5; it is not recorded as an owner decision.

Each group includes its focused tests and API/guide updates. Before its pull
request, run `mise run format`, `mise run check` and
`mise exec -- openspec validate --all --strict`. Use the existing browser stages
when paths, overlays or gallery output change. Do not create duplicate CI jobs.

## 1. Prove one crossing graph from source to styled playback

Bead: diagrams-w16.1

Depends on: none.

- [x] 1.1 Add a small Mermaid flowchart fixture with an unrelated crossing and a tight marked return; verify source conversion, semantic identities and the pre-change clearance/crossing behavior with focused assertions.
- [x] 1.2 Add the typed connector-option and final-path tracer through flowchart rendering; verify a curved crossing bridge, a plain-crossing comparison and a reserved terminal approach in four-target geometry/SVG snapshots.
- [x] 1.3 Bind the tracer scene and offline player to its final path; verify visible forward/reverse motion and a download equal to direct styled SVG in the existing browser harness.
- [x] 1.4 Document the tracer's public options, visual default changes and remaining coverage; verify executable examples and that it adds no published module or runtime dependency.

## 2. Complete connector styles and marker approaches for every kind

Bead: diagrams-w16.2

Depends on: group 1.

- [x] 2.1 Complete shared immutable path commands and typed style options, retaining original route-point access; verify elbow, rounded-elbow and smooth-curve geometry, invalid numeric settings and deterministic four-target serialization.
- [x] 2.2 Apply marker-aware straight terminal reservations in swimlane/flowchart, BPMN and architecture automatic routers and other marked connector adapters; verify all directions, both-end markers, short returns, self-loops, evenly spread shared-side attachments, clear top/bottom automatic approaches and actual outline/port attachment.
- [x] 2.3 Integrate sequence/ZenUML, architecture, BPMN, swimlane, flowchart, regex, EBNF and data-tree painters with final paths; verify each style preserves labels, line styles, semantic endpoints and kind-specific branch/join geometry.
- [x] 2.4 Add explicit supplied-BPMN display styling while preserving source bounds and waypoints by default; verify require/prefer/automatic policies, short imported approaches, unsafe-style diagnostics and unchanged source writing.
- [x] 2.5 Expose final path inspection and check final curves against labels, outlines and viewport bounds; verify constructed collisions, safe corpus cases, public consumer examples and updated option/geometry guides.

## 3. Complete crossing classification, bridges and limits

Bead: diagrams-w16.3

Depends on: group 2.

- [x] 3.1 Detect crossings on final line and curve geometry with stable ownership; verify interior crossings, multiple crossings, shallow angles, curve intersections, collinear overlap and deterministic ordering on all four targets.
- [x] 3.2 Exclude true endpoints, architecture junctions, shared trunks, branch splits/joins, sequence lifelines and shape/lane/pool borders; verify that bridges never change catalogs, shortest routes or reachability results.
- [x] 3.3 Build the owner-confirmed rounded-arch bridge hops and scoped local underpass masks for default bridge mode; verify dash/colour retention, plain mode, fixed/adaptive themes, tinted containers, nearby bends and arrow clearance in SVG and browser fixtures.
- [x] 3.4 Enforce candidate, subdivision, segment, crossing and output budgets and safe crowded-crossing handling; verify distinct invalid-option, routing-conflict and limit diagnostics without silent bridge omission or successful partial output.
- [x] 3.5 Document crossing priority, junction exclusions, bounds and supplied-path behavior; verify runnable examples, inline prefix isolation and the checker distinction between valid underpasses and actual bridge collisions.

## 4. Complete styled scenes, highlights and offline export

Bead: diagrams-w16.4

Depends on: groups 2 and 3.

- [x] 4.1 Replace independent scene path reconstruction with resolved final paths for every kind and retain local mask bindings; verify path equality, parallel-edge identity, collapsed endpoints, repeated occurrences and forward/reverse traversal.
- [x] 4.2 Apply crossing separation to selection, progress, moving tokens and configured regex/EBNF trace highlights; verify that an underpass overlay cannot paint a new joined crossing and that supplied evidence remains intact.
- [x] 4.3 Qualify direct SVG equality during export for each supported kind and connector style; verify position, occurrence, selection and speed retention with no new layout or provider invocation.
- [x] 4.4 Update playback guides and deterministic HTML snapshots; verify offline controls, keyboard use, still startup, reduced motion, hidden-page pause and print in the existing animation/browser suites.

## 5. Expand both galleries across all ten families

Bead: diagrams-w16.5

Depends on: group 4.

- [x] 5.1 Record the 15-card baseline and add three distinct source examples per sequence, ZenUML, architecture, BPMN, swimlane, flowchart, regex, EBNF, JSON and YAML family; verify at least 30 additional sources and 45 cards without counting theme, trace or player variants as sources.
- [x] 5.2 Cover different small, nested and dense supported structures and all three flowchart source forms; verify sources through current readers, public conversion APIs, final geometry checks and fixed light/dark rendering.
- [x] 5.3 Add same-model elbow, rounded-elbow and smooth-curve comparisons with bridge/plain variants and visible render settings; verify source and option reproduction, marked-endpoint clearance and final-path playback.
- [x] 5.4 Extend checked acceptance artifact producers, `scripts/gallery.mbtx`, generated site inventory and selected site assets; verify local/site parity, source downloads, both themes, offline players and unchanged existing IDs/detail URLs.
- [x] 5.5 Update gallery guidance and scope labels; verify generated artifacts, result counts, filters, no-script browsing, narrow viewports and root/next links using the existing gallery and site browser checks.

## 6. Qualify the integrated renderer and gallery

Bead: diagrams-w16.6

Depends on: group 5.

- [x] 6.1 Review affected SVG/HTML changes against the prior corpus; verify differences are confined to intended connector rendering, all frozen source inputs remain unchanged and new public interfaces are documented and generated.
- [x] 6.2 Run four-target workspace checks and fresh renderer/player consumers, then `mise run test:svg`, `mise run test:animation` and flowchart browser qualification; verify deterministic paths, mask references, all-kind motion and exact static export.
- [x] 6.3 Run `mise run gallery -- --qualify`, the site build/link/browser checks and root/next route-and-anchor compatibility; verify the full expanded inventory and record the review artifacts and results in the pull request.

## Workflow follow-up

- Prefer one implementation pull request when practical. Tick completed tasks in
  that pull request. The final group's pull request archives this change, syncs
  deltas and fixes archived HTML asset links before strict validation.
- After merge, close each delivered story with its PR and merge SHA. Close the
  epic only after all children are closed, point it at the archive, then run
  `bd dolt pull` followed by `bd dolt push` and verify success.
- Remove the delivered branch and confirmed stale generated backups. Keep
  unrelated work intact. Do not publish or cut a release.
