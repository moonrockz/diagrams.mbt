# Verification

All 26 implementation tasks and all 25 added requirements were checked before
archive. CI in the implementation pull request qualifies the committed tree.

| Capability | Requirement coverage | Evidence |
| --- | --- | --- |
| diagram-raster-export | Portable PNG/JPEG API, complete generated-SVG content, sizing/alpha/quality, deterministic GIF, binary results, bounds, shared browser path, cancellation/offline feedback | `tests/raster-spike/evidence.json`, `tests/raster-acceptance`, raster white-box tests, `test:raster-consumer`, `raster-test.ts`, `player-export-test.ts` |
| diagram-viewer-controls | Corner toolbar, bounded zoom/Fit, mouse/touch/keyboard pan, native/modal fullscreen, public hooks, independent instances/print/no-script | `viewer-test.ts`, local `gallery-test.ts`, published `browser-test.ts`, upstream Telescope PR 15 |
| diagram-animation | PNG/JPEG/GIF downloads, themed presentation, stored/explicit/system policy, viewport state preservation, public skin, compatibility | `test:animation`, four-target HTML snapshots, `player-export-test.ts`, documented player hooks |
| diagram-gallery | Card/detail/local downloads and viewport controls; exact source/SVG artifacts and no-script use | All 213 local previews converted and independently decoded; 328 local static digests; root/next 57-entry browser matrices; 311 published artifact byte checks |
| project-site | Selected A badge/header/favicon, preserved B/C/prompts, branded responsive landing and primary links/anchors | Root/next asset-byte checks and 360/768/1440 browser matrix; eight screenshots and visual review |

The owner-approved Telescope 0.4.0 release used its verified merge commit through
GitHub Actions. See `apps/site/verification-0.4.0.md` and the public release guide
for publication and actual public-consumer evidence. No sibling override or
workstation publication was used.

`mise run format`, `mise run check`, strict OpenSpec validation, stored SVG and
animation browser suites, fresh portable raster/flowchart/state consumers, and
root/next site consumer checks passed. The final local gate had 930 tests on
each portable backend, 941 on native and 28 task-script suites. Source/static
SVG inventory remained exact; historical archive assembly code was unchanged.

Independent review's glyph allocation, cmap expansion and signed-wrap findings
were fixed and re-reviewed. Regression tests enforce early aggregate budgets
and successful outlining/subsetting of the formerly crashing valid font.

Continued PR review found a custom-limit GIF timestamp allocation that preceded
the cumulative-pixel check. Both sampler and worker paths now preflight pixel
and minimum byte budgets before allocating timestamps. Regressions exercise a
2,147,483,647-frame request with tiny pixel/output budgets without materializing
its schedule.

Offline generated HTML and JavaScript include complete converter/font license
notices. Exact source copies are retained; generated comments use LF so HTML
parsing and cross-checkout asset validation preserve their text.

The existing Zig CI gate has optional bounded Linux resource/process diagnostics
for runner shutdown investigation. It keeps the pinned full native test
command and coverage, propagates its exit status and excludes process arguments/environment.

The hosted trace measured four concurrent Zig compiler processes at 14.76 GiB
combined RSS, about 111 MiB available RAM and 2.09 GiB swap use before runner
shutdown. Only this gate now uses `--jobs=2`, with a 30-minute allowance for the
reduced parallelism. The selected OS, compiler pin and full suite remain the same.

Sizing review found one-ULP errors on actual state/flowchart/YAML/sequence
viewBoxes. Explicit axes are exact; integral derived dimensions and Fit
comparisons use bounded Int64 ratios. Fractional inputs have a guarded floating
path. Portable regressions include public PNG/JPEG decoding, exact dimension
budgets and architecture/swimlane exact-aspect cases. The prior capped Linux
Zig run passed all 937 then-current native tests in 13m20s, with peak combined
compiler RSS 10.25 GiB and at least 4.67 GiB available RAM.
