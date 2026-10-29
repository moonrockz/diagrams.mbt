# Tasks

## 1. Qualify portable raster conversion with a vertical spike

Bead: diagrams-87x.1

- [x] 1.1 Build an unpublished acceptance fixture that converts actual generated SVG to PNG and JPEG and a two-frame GIF using published candidate raster/font/codec packages; verify compile and execution on wasm, wasm-gc, JavaScript and native without a browser, external converter or sibling checkout.
- [x] 1.2 Qualify text and font coverage, icons, CSS/theme resolution, paths, transforms, clipping, connector masks and binary decoding against representative generated fixtures; record independent decoded-image comparisons and the exact dependency versions, licenses and target results.
- [x] 1.3 Resolve all spike gaps before production adoption and update design RAS-1 with the selected backend and explicit supported generated-SVG profile; verify no required target or diagram family was dropped and list remaining implementation work as specific tasks.

## 2. Add the supported PNG and JPEG library API

Bead: diagrams-87x.2

Depends on group 1.

- [x] 2.1 Add the optional raster library, typed binary result and validated format/options types without changing existing text-renderer signatures; register workspace membership and shared versions, and verify a fresh standalone consumer builds on all four targets.
- [x] 2.2 Implement generated-SVG normalization, explicit theme and font resolution and bounded raster conversion; verify every implemented diagram family, labels, icons, curves, clip paths and crossing masks with independent decoded-pixel acceptance fixtures.
- [x] 2.3 Encode PNG with optional alpha and JPEG with explicit opaque background and quality; verify signatures, decoded dimensions, transparency/background, non-cropped content, equal target bytes and unchanged inputs.
- [x] 2.4 Enforce overflow-safe limits and diagnostics for invalid options, missing required glyphs, malformed/unsupported input and output exhaustion; verify focused failure tests and checked API examples, and document font inputs, limits and the generated-SVG scope.

## 3. Add deterministic animated GIF export

Bead: diagrams-87x.3

Depends on group 2.

- [x] 3.1 Sample source-bound playback plans into export frames, including repeated and concurrent occurrences, node visits, reversed curves and masks; verify frame samples against pure plan samples and existing path geometry.
- [x] 3.2 Encode bounded multi-frame GIF with dimensions, background, interval, frame rate and loop options; independently decode frames, first/final views, delays, palette, loop setting and moving pixel regions on all targets.
- [x] 3.3 Enforce frame, cumulative-pixel and byte budgets without mutating scene or plan; verify invalid/bounded/finite/repeating cases and target byte equality, and document GIF timing, quantization and transparency limits with executable examples.

## 4. Refresh the shared standalone player and viewport control

Bead: diagrams-87x.4

Depends on groups 2 and 3 for export integration.

- [x] 4.1 Add scoped public root/part classes and CSS variables, light/dark/system shell colors and guarded site-theme preference handling; document a per-instance custom skin and verify computed styles, explicit-theme precedence and blocked storage.
- [x] 4.2 Add a clear header, large stage, primary playback action, timeline, status and grouped exploration/export panels while retaining existing control hooks; verify keyboard use, both themes and 360/768/1440 pixel layouts.
- [x] 4.3 Add fixed top-right fullscreen, bounded zoom, scale, fit and pointer/keyboard pan with native and modal fullscreen paths; verify pointer cancellation, focus/scroll restoration, touch use, resize, independent viewers, selection handling and unchanged playback state.
- [x] 4.4 Embed a browser-compatible adapter of the supported raster library and add PNG/JPEG/GIF export options, busy/progress state and cancellation; verify downloaded data matches library results, failure recovery, no external requests and unchanged live state.
- [x] 4.5 Regenerate trusted runtime embedding and reviewed player HTML snapshots; run existing animation browser and portable suites for all diagram families, hostile labels, reduced motion, page visibility, print and exact canonical SVG export, and update the player guide.

## 5. Prepare shared Telescope gallery and branding support

Bead: diagrams-87x.5

Depends on groups 2 and 4 for the export and styling contracts.

- [x] 5.1 Create the matching change in Telescope's own planning scope and implement gallery card/detail viewport controls with the public styling contract; verify navigation isolation, both themes, no-script output, narrow layouts and custom skins in its browser suites.
- [x] 5.2 Expose supported host integration for the diagrams raster download adapter and local export assets without adding a diagrams UI framework dependency; verify PNG/JPEG downloads, failure feedback and original SVG actions through a real consumer fixture.
- [x] 5.3 Add or use supported Telescope brand asset inputs for the header and favicon; verify base-path/version-tree asset URLs and document the consumer configuration.
- [x] 5.4 Prepare release-ready upstream changes and verification evidence, then obtain required owner release approval and confirm an approved published library and matching CLI exist before production pin adoption; verify a fresh consumer can install those artifacts without a sibling checkout.

## 6. Integrate the local gallery, published gallery and branded landing page

Bead: diagrams-87x.6

Depends on groups 4 and 5.

- [x] 6.1 Adopt the qualified published Telescope library and CLI with verified archive hashes; verify fresh root and next consumer builds, existing route/anchor compatibility and unchanged historical archive assembly.
- [x] 6.2 Add the same viewport behavior and PNG/JPEG actions to every generated local gallery image panel using supplied offline assets; verify local file use, all preview images, multiple viewers and unchanged source/static SVG digests in gallery browser checks.
- [x] 6.3 Connect published gallery downloads to the supported raster API adapter and qualify cards/detail pages; verify downloads match library results and filters, tabs, source copy, links and SVG downloads retain their behavior.
- [x] 6.4 Redesign the landing page around the selected A badge, clear primary links and supported family previews, and configure header/favicon assets; verify all image sizes, both themes, narrow layout, root/next URLs and preserved anchors, and retain the B/C originals and prompts.
- [x] 6.5 Regenerate qualified current gallery/player artifacts and update site and gallery guides for controls and exports; verify no-script static use, no unexpected source/SVG changes and link checks in both version trees.

## 7. Qualify the complete change

Bead: diagrams-87x.7

Depends on all prior groups.

- [x] 7.1 Run integrated raster, local/published gallery, SVG, animation and site consumer qualification with offline export and independent binary decoding; verify styling hooks, fullscreen fallback, cancellation and existing support limits together.
- [x] 7.2 Run mise run format, mise run check and mise exec -- openspec validate --all --strict; verify all pass and review generated interfaces and current HTML changes without accepting altered source/SVG bytes or historical archives.

## Workflow follow-up

- Create one epic and one story per numbered group after maintainer approval. Add the dependencies above and claim the current story.
- Shared Telescope source work belongs in its own change and pull requests. This repository's proposal does not itself cut a release or authorize publication.
- Archive this change in the last task group's pull request and fix artifact links as required.
- Close stories and the completed epic only after merge, with the pull request and merge SHA, then sync beads as CONTRIBUTING.md requires.

