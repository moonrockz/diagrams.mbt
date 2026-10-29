# Tasks

## 1. Add shape-aware anchors through the shared router

Bead: diagrams-q4b.1

- [x] 1.1 Add a minimized diamond regression and the existing review/escalation cases to the real layout seam; verify current off-point endpoints are reproduced and expected clear-point behavior is testable.
- [x] 1.2 Implement a pure bounded attachment profile and candidate/route selection in shared swimlane geometry; verify clear diamond points in TB/BT/LR/RL, non-square bounds, marker approaches, usable box spans and rounded outlines.
- [x] 1.3 Add fan-in/out, parallel, reciprocal, self-loop, crowded and explicit-direction cases; verify distinct terminal corridors, real-outline attachment, unchanged identities, safe fallback locations and limit diagnostics.
- [x] 1.4 Document default preferences and fallback behavior, and qualify the shared helper and swimlane/flowchart/state adapters on all four targets with stable geometry and source-model equality tests.

## 2. Integrate automatic BPMN and qualify complete outputs

Bead: diagrams-q4b.2

Depends on group 1.

- [x] 2.1 Use the same attachment policy in automatic BPMN routing and retain authored architecture and state-boundary constraints; verify gateway points, event/box outlines, explicit sides and unchanged default supplied waypoints.
- [x] 2.2 Qualify all connector styles and marker sizes against actual outlines, labels, containment and final geometry; verify existing checkers report genuine collisions and no preferred-anchor exception bypasses them.
- [x] 2.3 Review and regenerate only affected connector snapshots, scenes and qualified gallery artifacts; verify static SVG, playback overlays, PNG and GIF use identical final anchors, paths and masks while source syntax and graph semantics stay unchanged.
- [x] 2.4 Update affected rendering and gallery guidance with the reproduced decision examples and before/after comparisons; verify portable equality and focused SVG, animation and raster acceptance suites.

## 3. Add source tabs in the shared Telescope gallery

Bead: diagrams-q4b.3

- [ ] 3.1 Create a matching upstream Telescope change and reuse shared source panels for index cards with unique per-entry tab/panel IDs; verify exact declared source, multiple filenames, copy/download actions and independent card state.
- [ ] 3.2 Implement accessible keyboard tabs and no-script source fallback while preserving mounted viewer instances; verify retained zoom/pan, repeated hide/show, fullscreen/export controls, filters, detail links and clipboard-denied behavior.
- [ ] 3.3 Add shared styling hooks and source-text escaping tests; verify hostile input, narrow source scrolling, both themes, missing optional source, local assets and stable version-tree URLs in upstream browser/consumer checks.
- [ ] 3.4 Prepare and qualify the upstream library and matching CLI release under its repository rules, obtain any separately required release approval, and verify published artifacts exist before consumer pin adoption.

## 4. Adopt source tabs and extend the local gallery

Bead: diagrams-q4b.4

Depends on groups 2 and 3.

- [ ] 4.1 Adopt the qualified published Telescope library/CLI and verified archive hashes; verify a fresh diagrams.mbt consumer builds root and next without a sibling checkout or generated-HTML patches.
- [x] 4.2 Associate local gallery examples with original declared text and add Preview/Source inspection shared across theme variants; verify offline source text and downloads and explicit source-unavailable handling for model-only fixtures.
- [ ] 4.3 Extend the existing gallery browser matrix for index/detail/local source tabs, multiple sources, exact text, keyboard/no-script reading and 360/768/1440 widths; verify retained viewport state, filters, source URLs and raster actions.
- [ ] 4.4 Update site and local-gallery documentation and checked artifacts; verify root/next route/anchor compatibility and unchanged original source and historical release bytes.

## 5. Verify the combined change

Bead: diagrams-q4b.5

Depends on all prior groups.

- [ ] 5.1 Run combined SVG, animation, raster, local-gallery and published-site browser qualification; verify natural attachments and their source text together in both themes and version trees.
- [ ] 5.2 Run mise run format, mise run check and mise exec -- openspec validate --all --strict; verify all pass and inspect generated interfaces and reviewed connector-only snapshot changes.

## Workflow follow-up

- After maintainer approval, create one epic and one story per numbered group, add the dependencies above and claim the active story.
- Keep upstream Telescope work in its own change and PRs. Follow repository release and publication gates.
- Archive this change in the final task-group PR. Close stories and the finished epic only after merge with PR and merge SHA, then sync beads.

