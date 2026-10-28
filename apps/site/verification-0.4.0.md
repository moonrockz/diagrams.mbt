# Telescope 0.4.0 adoption verification

The owner approved the release PR, normal merge and Actions publication on
2026-10-28. [Release PR 16](https://github.com/moonrockz/telescope/pull/16)
merged at `8ab416c7f6e1fc1973f5a4b0caac628978f0895f`. The owner-gated
[publication run](https://github.com/moonrockz/telescope/actions/runs/40767534086)
published that exact verified commit. Both platform qualifiers and actual public
Linux and macOS consumers passed. [Evidence PR 17](https://github.com/moonrockz/telescope/pull/17)
retains the public installation reports and checksums in the
[release guide](https://github.com/moonrockz/telescope/blob/main/docs/release/0.4.0.md).
Upstream stories closed after merge, and Dolt pull and push succeeded.

The consumer pins `moonrockz/telescope@0.4.0` and the matching released CLI.
[Installation](README.md#pinned-installation) records both archive hashes.
An independent comparison confirmed installed host sources equal the actual
published library ZIP, SHA-256
`cfa50ef42ed30b1dbbcda36386a661dbfe3648c79b6491c3095fd1f09a237b40`.
There is no sibling checkout, path override or generated-HTML patch.

`mise run test:site-consumer` built fresh root and next output with 0.4.0
provenance. Both link checks and the frozen 77-route, 5,376-anchor baseline
passed. All 57 gallery entries and all 311 supplied artifact bytes matched the
current qualified input. The source/static SVG inventory also retained all 235
pre-change digests. Current player HTML changes are reviewed generated output.
Historical archive assembly code and its asset selection remain unchanged;
versioned assembly tests continue to consume existing archives without rebuilding.

`site/site.json` uses supported `header_logo`, `favicon` and
`gallery_raster_adapter` fields. Static mappings supply brand icons and the
compiled portable conversion worker. The site imports Telescope only in the
unpublished consumer. Published libraries import no UI framework.

The final browser runs passed for root and next. Each covered 57 entries and
684 responsive detail cases, eight real UI PNG/JPEG conversions equal to the
compiled portable adapter, and four additional byte comparisons with the
four-target portable fixtures. Both checked branding asset bytes, all primary
links, filters, tabs, source actions, option capture during pending work,
cancellation, bounded failure, SVG availability and recovery. Eight landing
screenshots covered both trees, both themes and 360/1440 widths; visual review
found no clipping. The existing matrix also covers 768 pixels and no-script use.

The complete local gate passed with 926 tests on wasm, wasm-gc and JavaScript,
937 on native, 28 task-script suites, all validation and builds. Independent
review checked raster/GIF bounds, geometry, source binding and the worker
protocol. Three font findings were fixed and reviewed again: aggregate glyph
preflight, cmap expansion precharge and signed-wrap cmap normalization. The
original font panic reproducer now succeeds, including font subsetting.

Continued PR review also moved cumulative-pixel and minimum-byte GIF budget
checks ahead of timestamp allocation. Public sampler/worker regressions cover
enormous custom frame limits with small remaining budgets.

[Native Zig telemetry](https://github.com/moonrockz/diagrams.mbt/actions/runs/40784881127/job/123156125023)
recorded four concurrent compiler processes using 14.76 GiB combined RSS on a
16 GiB host immediately before shutdown. That gate now limits Moon parallelism
to two jobs and allows 30 minutes, retaining all native tests and the compiler
pin. Resource diagnostics remain available.
