# Telescope 0.2.0 adoption verification

Verified on 2026-10-27 against consumer base
`891f3f650e7790fef8c88433bc11b0f3bfdf1264` with the adoption changes applied.
Current-head CI verifies the final committed tree in the adoption PR.

## Released inputs

The owner-approved [Telescope release run](https://github.com/moonrockz/telescope/actions/runs/40573188390)
published `moonrockz/telescope@0.2.0` and matching Linux x64/macOS arm64 CLI
archives from `597f50ab27ffc116d50b48c7a402a250ade856b2`. Both platforms passed
actual public installation without local path or workspace overrides.
[Installation](README.md#pinned-installation) records the consumer pins and
checksums; the [release guide](https://github.com/moonrockz/telescope/blob/main/docs/release/0.2.0.md)
retains both public-consumer reports.

Orca Run `run_b3638d9bfa3d` delivered those coordinates in reply
`msg_6d438f4a1064` to dispatch `ctx_60be8ee3e9f8`. The worker acknowledged the
release gate in `msg_32f040eca8d9` before changing pins. The coordinator inspected
the real module and both CLI pins after receiving the acknowledgement.

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
| `mise run test:site-consumer` in working and fresh checkouts | Real 0.2.0 provenance at root and next; all 77 routes, 5,376 anchors, 12 examples, nine families and 40 artifact bytes retained |
| Fresh `mise run test:site` and `mise run test:site -- --tree next` | Both strict browser suites and 11 native consumer/assembly tests per invocation passed |
| Strict browser matrix | Both themes, 360/768/1440 widths, no-script reading, system/stored themes, keyboard focus, shared landing/docs/API/gallery palette, cards, family/text filtering, empty/reset, Preview/Source keyboard tabs, exact source/download text and clipboard-denied fallback passed |
| Existing renderer/player coverage | 120 standalone, 185 BPMN, 193 swimlane and 25 PlantUML SVG outputs, BPMN XML and offline playback passed |

The existing missing-API-prose diagnostics remain visible, with 3,831 warnings
per site build. No published library imports Telescope, Rabbita or browser UI.
Gallery manifest version 1, renderer palettes, support labels and artifact inputs
remain unchanged. BPMN playback remains illustration; regex/EBNF evidence remains
externally supplied. Manual light/dark desktop and 360-pixel visual checks passed.

## Historical release assembly

The fresh consumer ran `mise run assemble:site` and `mise run check:site` using
actual historical release downloads. It then ran the released 0.2.0 CLI's
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
latest without invented canonicals. All 15,752 repository source links retain
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
