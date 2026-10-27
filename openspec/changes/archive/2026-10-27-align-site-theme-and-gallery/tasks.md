# Tasks

## 1. Adopt and prove the published shared presentation

Bead: diagrams-cgy.1

Acceptance: A fresh checkout uses the actual published Telescope library and matching CLI and produces the shared Smithy-aligned site without local source dependencies or duplicated presentation code.

- [x] 1.1 Receive the actual Telescope release version, source revision, native archive URLs and checksums, and both public-consumer reports; verify the release exists before changing the current 0.1.1 pins.
- [x] 1.2 Update the published module and CLI pins and related consumer assertions; verify `mise run test:site-consumer` from a fresh checkout outside Telescope workspaces with no local overrides.
- [x] 1.3 Extend site browser acceptance for shared palette values on landing, docs, API and gallery pages and for the 12 preview cards; verify light, dark and system themes and visible keyboard focus.
- [x] 1.4 Update site installation and gallery documentation with the actual release and run format, strict OpenSpec validation and `mise run check`; verify diagram libraries remain free of site/UI dependencies.

## 2. Qualify gallery interaction and versioned deployment

Bead: diagrams-cgy.2

Acceptance: All existing examples, links and artifact bytes remain compatible, the new gallery behavior works across access modes, and historical site assembly retains the accepted version policy.

- [x] 2.1 Extend strict gallery browser checks for family/text filtering, counts/reset, Preview/Source keyboard behavior, source copy fallback and explicit downloads/player links; verify both themes at 360, 768 and 1440 CSS pixels and without JavaScript.
- [x] 2.2 Verify all 12 stable example detail routes, existing family anchors, nine families and 40 byte-identical artifacts under root and next bases; confirm BPMN illustration and external regex/EBNF evidence labels remain unchanged.
- [x] 2.3 Run route/anchor compatibility and real historical archive assembly checks; verify historical bytes, canonical/source links and root/latest/minor/next roles without rebuilding release tags.
- [x] 2.4 Document final consumer evidence and next-site location, run required full/site checks and prepare the final adoption PR with this change archived; verify review findings and current-head CI before seeking merge approval.

## Workflow follow-up

- After approval, create one repository-local epic and two stories; group 2 depends on group 1, which waits for the actual Telescope release.
- Coordinate release and integration evidence through `run:run_b3638d9bfa3d`.
- Archive in the final implementation PR and repair relative HTML asset paths. Close stories only after merge, with PR and merge SHA; close the finished epic and sync.
- After an authorized merge, verify Pages deployment provenance, representative page types, all gallery details and downloads; retain `/next/` as the current development site.
