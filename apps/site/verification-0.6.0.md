# Telescope 0.6.0 verification

The owner approved publication of Telescope 0.6.0 at source
`3bc7acf1a050188ecbe5ba06e3d024af4a54b18d`
([release PR 26](https://github.com/moonrockz/telescope/pull/26),
[release run 42413714875](https://github.com/moonrockz/telescope/actions/runs/42413714875)).
The [0.6.0 release guide](https://github.com/moonrockz/telescope/blob/main/docs/release/0.6.0.md)
lists the changes. Telescope 0.6.0 requires MoonBit 0.10.20. On the 0.10.20 js target
a MoonBit `Array` is not a raw JavaScript array, so 0.6.0 changes the search island and
the version switcher to receive `FixedArray`.

The site pins `moonrockz/telescope@0.6.0` and the matching CLI v0.6.0 on MoonBit
`0.10.20+65efd5b93`. The site source did not change: the 0.6.0 public API is the same
for this consumer. The CLI archive digests in [Installation](README.md#pinned-installation)
are equal to the GitHub asset digests and to the `.sha256` companion files.

Checks on macOS arm64, 2026-11-07:

- `mise run test:site-consumer`: root and next with 0.6.0 provenance, the 77-route and
  5,376-anchor baseline, 57 gallery entries and 311 byte-preserved artifacts.
- `mise run check:site -- --tree next`, `mise run check:site-compatibility -- --out _site/next`,
  and `mise run check:site` after `mise run assemble:site`: pass.
- `mise run test:site -- --tree next`: 57 entries, 684 responsive detail cases and 8 real
  UI conversions that match the compiled library.
- `mise run test:animation`: pass.

Search and the version picker were checked in headless Chromium (Playwright 1.64.1) on
the assembled site (`/diagrams.mbt/next/`, with the release trees 0.1 to 0.4), before
the change (MoonBit 0.10.18, Telescope 0.5.0) and after it (MoonBit 0.10.20,
Telescope 0.6.0). Both runs gave the same result:

| Check | Before | After |
| --- | --- | --- |
| Search "diagram" shows results | pass (10) | pass (10) |
| Enter opens the first result | pass | pass |
| A query without a match shows "No results" | pass | pass |
| The version picker lists Latest (0.4), main, 0.4, 0.3, 0.2 and 0.1 | pass | pass |
| Choosing Latest (0.4) opens `/diagrams.mbt/latest/` | pass | pass |
| No console errors | pass | pass |
