# Telescope 0.2.1 adoption verification

Verified on 2026-10-27 against consumer base
`8726c8535d316b93b8ff1917f7df245ab28ea413` with the adoption changes applied.
Current-head CI verifies the final committed tree in the adoption PR.

## Released inputs

The owner-approved [Telescope release run](https://github.com/moonrockz/telescope/actions/runs/40594390130)
published `moonrockz/telescope@0.2.1` and matching Linux x64/macOS arm64 CLI
archives from `1f84c6c8de780ea9322db6eef14c10395a4670f9`. Both platforms passed
actual public installation without local path or workspace overrides.
[Installation](README.md#pinned-installation) records the consumer pins and
checksums; the [release guide](https://github.com/moonrockz/telescope/blob/main/docs/release/0.2.1.md)
retains both public-consumer reports.

The coordinator verified the real Linux public install in the release job and an
independent actual macOS public install, then checked both checksum companions
against GitHub asset digests before changing consumer pins. Orca Run
`run_b3638d9bfa3d` remains the shared coordination record. The actual 0.2.1 pins
and downstream verification follow that published evidence, without a local
source dependency.

## Consumer and browser checks

All commands below passed. A fresh ordinary clone outside Telescope workspaces
started without dependency or build caches. Only the reviewed consumer changes
were overlaid; it resolved the actual public module and downloaded the matching
native CLI and checksum companions. No Telescope source checkout or registry
seed was supplied.

| Check | Observed result |
| --- | --- |
| `mise run format`, `mise run check` | Full repository format, lint, workspace/version validation, all four backend test suites, task tests and builds passed |
| `mise exec -- openspec validate --all --strict` | Passed; unrelated draft changes preserved |
| `mise run test:site-consumer` in working and fresh checkouts | Real 0.2.1 provenance at root and next; all 77 routes, 5,376 anchors, 12 examples, nine families and 40 artifact bytes retained |
| Fresh `mise run test:site` and `mise run test:site -- --tree next` | Both strict browser suites and 11 native consumer/assembly tests per invocation passed |
| Strict browser matrix | Both themes, 360/768/1440 widths, no-script reading, system/stored themes, keyboard focus, shared landing/docs/API/gallery palette, cards, family/text filtering, empty/reset, Preview/Source keyboard tabs, exact source/download text and clipboard-denied fallback passed |
| Existing renderer/player coverage | 120 standalone, 185 BPMN, 193 swimlane and 25 PlantUML SVG outputs, BPMN XML and offline playback passed |

The existing missing-API-prose diagnostics remain visible, with 3,831 warnings
per site build. No published library imports Telescope, Rabbita or browser UI.
Gallery manifest version 1, renderer palettes, support labels and artifact inputs
remain unchanged. BPMN playback remains illustration; regex/EBNF evidence remains
externally supplied. Manual light/dark desktop and 360-pixel visual checks passed.

## Reset control correction

The actual released 0.2.1 build passes geometry and color checks at 1440, 768 and
360 pixels in both themes. On shared toolbar rows the reset and textbox edges
match exactly at 45.17 CSS pixels high. Phone layouts wrap without overflow.
The toolbar and empty-state resets use the shared accent/on-accent colors and
both restore all twelve cards. Button text contrast is 6.29:1 in light mode and
8.02:1 in dark. The review preview now serves the actual downloaded release.

## Historical release assembly

The fresh consumer ran `mise run assemble:site` and `mise run check:site` using
actual historical release downloads. It then ran the released 0.2.1 CLI's
`assemble` and `check` on the exact same supplied input manifest. Both produced
499 identical output files. Existing historical tags and archives were not rebuilt.

| Release archive | Source revision | Verified SHA-256 |
| --- | --- | --- |
| [v0.1.0 / site-0.1.tar.gz](https://github.com/moonrockz/diagrams.mbt/releases/download/v0.1.0/site-0.1.tar.gz) | `971e6ae7bcc22c3e3aa921df8ccddec51f2fc821` | `47afa04889f5b2ae33c6fe9435a43f39721c4c94f13eb33e71680601e71f7339` |
| [v0.2.0 / site-0.2.tar.gz](https://github.com/moonrockz/diagrams.mbt/releases/download/v0.2.0/site-0.2.tar.gz) | `9fe29cc00e745379f5a66b915107cc4fc7c43a89` | `5fd74a2ee6db15fde9d65788c7f6a32f467d173ca861f6e8bc9e950174f3c23a` |

Both downloads match GitHub asset digests and the previously checked archives.
All 28 v0.1 input files and 81 v0.2 input files match fresh archive extraction.
The outputs preserve historical static assets and all 40 next gallery artifacts.
Each output retains 259 latest-route canonicals and leaves 73 routes absent from
latest without invented canonicals. All repository source-link attributes retain
their supplied values; 15,683 generated API source links identify the correct
release or next revision. Authored repository links remain authored links.

`versions.json` retains `latest=0.2`, `next=true` and minors `0.2`, `0.1`.
Root, latest and v/0.2 preserve the historical release presentation; v/0.1 has its
older-version banner. Next remains unreleased with the new shared gallery.

## Deployment boundary

The development site belongs at
[https://moonrockz.github.io/diagrams.mbt/next/](https://moonrockz.github.io/diagrams.mbt/next/).
This record proves local released-consumer compatibility. Merge and Pages
provenance checks remain separate gates; it does not claim this adoption is
already deployed or publish a new diagrams library version.
