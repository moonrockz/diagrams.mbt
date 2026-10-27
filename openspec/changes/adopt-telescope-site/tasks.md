# Tasks

Implementation is approved. The consumer pins the actual published Telescope library and CLI 0.1.0 from owner-approved Actions run 40520332727. Clean public installs pass on Linux and macOS. A fresh diagrams checkout preserves 77 routes, 5,376 anchors, 12 gallery examples and 40 artifact bytes at root and next. Historical 0.1/0.2 archives assemble through the released host and CLI. Strict browser and canonical acceptance exposed four shared 0.1.0 gaps; Telescope PR 5 prepares an unpublished 0.1.1 fix. Keep actual pins and remaining acceptance pending its owner-approved publication. The epic and stories stay open until merge.

## 1. Prove the released consumer path

Bead: diagrams-3dz.1

- [x] 1.1 Record the published Telescope library and CLI versions and pin them in the site dependencies; verify a clean dependency install without a sibling checkout or path override.
- [x] 1.2 Capture the current docs/API/article routes and anchors, version metadata and representative rendered pages; verify the capture against the existing site build and preserve the inventory for comparison.
- [x] 1.3 Build a landing page, one docs page and one sequence gallery detail through a thin `apps/site` consumer; verify the published toolkit produces them below `/diagrams.mbt/` and `/diagrams.mbt/next/` in a fresh checkout.
- [x] 1.4 Add the focused consumer integration check and document the pinned dependency setup; verify the documented command builds and checks this path with no unpublished Telescope inputs.

## 2. Migrate the existing documentation site

Bead: diagrams-3dz.2

- [x] 2.1 Route Markdown, HTML, package READMEs and API pages through the released content and view packages; verify routes and anchors against the baseline and run the relevant existing content/API tests.
- [ ] 2.2 Use the shared shell, navigation, search, themes and browser controls; verify keyboard focus, mobile navigation, code copy and no-script reading with the focused browser suite.
- [ ] 2.3 Connect released version-tree support to the local release-asset assembly boundary; verify next, minor, root and latest trees using historical site archives and the existing tree-aware link checks.
- [ ] 2.4 Remove the copied shared engine once its callers use the released toolkit, and update the site developer guide; verify no duplicate parser/theme/route implementation remains and `mise run build:site`, `check:site` and `test:site` pass.

## 3. Add the diagram gallery and landing content

Bead: diagrams-3dz.3

- [x] 3.1 Export a versioned gallery manifest from the checked example pipeline with stable IDs, support labels, artifact paths; verify valid inputs pass and duplicates, missing files, traversal and escaped symlinks fail.
- [x] 3.2 Add source downloads, readable SVG previews and optional qualified offline player links for sequence, ZenUML, architecture, BPMN, swimlane, regex, EBNF, JSON and YAML; verify each link and required file and run the corresponding existing SVG/player qualification checks.
- [ ] 3.3 Add the gallery index, stable detail pages and primary navigation link; verify family navigation and downloads under both root and next base paths, without JavaScript and in both themes at desktop and narrow widths.
- [x] 3.4 Update the landing page and example descriptions to match implemented support; verify links to docs/gallery and assertions for planned formats, BPMN illustration limits and externally supplied trace evidence.
- [x] 3.5 Document how to add and qualify an example; verify the documented procedure adds a fixture example through the released gallery contract without editing Telescope internals.

## 4. Qualify the integrated consumer and deployment path

Bead: diagrams-3dz.4

- [ ] 4.1 Run `mise run format`, `mise run check`, the site build/check/browser suites and strict OpenSpec validation; record actual results and verify the published diagram libraries have no Telescope or Rabbita dependency on all four targets.
- [ ] 4.2 Adapt the existing site CI inputs and cache keys to pinned Telescope artifacts where needed; verify a pull-request build produces the checked site artifact and a deployment dry run retains historical release assembly.
- [ ] 4.3 Send the pinned versions, route comparison and gallery/browser results to the Telescope workspace through the Orca Run; verify receipt and resolution of any integration issues before merge.

## Workflow follow-up

- The last implementation pull request archives this change and repairs HTML asset paths. Run strict validation after archive.
- After merge, close completed beads with the PR and merge SHA, close a finished epic, sync the tracker and delete the branch as CONTRIBUTING.md requires.
- Deploy the checked site through the existing GitHub Actions workflow. Do not cut a package release from a workstation.
