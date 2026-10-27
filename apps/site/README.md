# diagrams.mbt site consumer

`moonrockz/diagrams-site` is an unpublished native consumer of
[`moonrockz/telescope@0.1.1`](https://mooncakes.io/docs/moonrockz/telescope).
The published diagram libraries have no Telescope or UI dependency.

`consumer/` supplies compiled Mermaid and PlantUML fence callbacks to the released
`host.build` API. They preserve `figure.diagram`, the legacy SVG ID seeds, and one
occurrence counter for both `plantuml` and `puml`. The consumer records the actual
Git revision in `_build/site-config.json` for page and API source links.
`assemble/releases.mbt` owns GitHub tag selection, `versions.since`, and the
`site-<minor>.tar.gz` asset policy. Its host boundary downloads existing archives
and supplies them, together with `next`, to Telescope's offline assembler.

Telescope owns configuration validation, content parsing, API ingestion, routes,
HTML, navigation, search, themes, browser controls, static assets, checks, serving
and generic version assembly. There is no local copy of those engines.

## Pinned installation

Use the tools in `.config/mise/config.toml` and run from the repository root:

```shell
mise trust
mise install
mise exec -- moon update
mise run test:site-consumer
mise run test:site -- --tree next
```

`test:site-consumer` builds and checks root and `next`, compares the unchanged
77-route and 5,376-anchor compatibility baseline, and checks all 12 gallery
entries and the exact bytes of their 40 supplied artifacts. It writes
`_build/site-consumer-report.json`. `-- --existing-output` checks builds already
on disk. No Telescope checkout, path override or source build is used.

`scripts/telescope.mbtx` downloads CLI **v0.1.1** from the
[GitHub release](https://github.com/moonrockz/telescope/releases/tag/v0.1.1), verifies
both the pinned SHA-256 and companion checksum, extracts it below
`_build/tools/telescope/`, and checks `--version` before use. It supports the
release's qualified Linux x64 and macOS arm64 archives:

| Archive | SHA-256 |
| --- | --- |
| `telescope-0.1.1-linux-x64.tar.gz` | `dbd2e1813b6d1a7d16bf88e022cd5e971209811fc12c2cf3c7955d6270dca4de` |
| `telescope-0.1.1-macos-arm64.tar.gz` | `10fc718ff86184a8d21cb77aec0dfff3ad35c16008d8de0b5bbd272a274a1036` |

The owner-approved [release run](https://github.com/moonrockz/telescope/actions/runs/40531421002)
published source `4c2c7ebb235425c917780fccfc874a5beb06c156`. See the
[0.1.1 release guide](https://github.com/moonrockz/telescope/blob/main/docs/release/0.1.1.md)
for the public-install qualification. The downloader never substitutes a
binary from PATH or rebuilds Telescope. The library and CLI embed their CSS and
browser islands; Bun installs only the locked browser test dependencies.

## Commands and content

```shell
mise run build:site
mise run check:site
mise run test:site
mise run dev:site
mise run build:site -- --main --tree next
mise run check:site -- --tree next
mise run assemble:site
mise run check:site
```

`dev:site` invokes the released CLI at
`http://127.0.0.1:4173/diagrams.mbt/`. A local source watcher rebuilds changes.
`-- --port 4175 --no-watch` selects another port and disables watching.

| Input | Output |
| --- | --- |
| `docs/<path>.md` or `.html` | `/docs/<path>/` |
| Selected package README | `/docs/packages/<name>/` |
| `site/pages/index.html` | `/` |
| Dated `site/articles/` content | `/articles/<slug>/` and Atom feed |
| Selected `moon doc` metadata | `/api/<qualified-package>/` |
| `site/gallery.json` | `/gallery/` and `/gallery/<id>/` |

`site/site.json` declares schema version 1, explicit discovery roots, navigation,
API modules, static examples and the gallery artifact root. Local plans below
`docs/superpowers/` stay excluded. `build:site` runs `moon doc` for each selected
API module into `_build/site-api`; missing API prose remains visible as warnings.
Builds use Telescope's staged promotion, preserving the previous tree on failure.

`--tree <minor>` builds `_site/v/<minor>/` only for the root module's current
minor line. `assemble:site` downloads the newest eligible historical release in
each minor line, supplies its existing archive without rebuilding it, and writes
root, `next`, `v/<minor>`, `latest`, banners and `versions.json`. Historical trees
are staged in `_build/site-assembly-input`. `check:site` checks the assembled
output tree by tree. Assembly requires GitHub read access through `gh`.

## Add and qualify an example

Update a tested renderer source or fixture first, then add an entry to
`site_gallery_examples` in `scripts/gallery.mbtx`. Choose a stable ID and family,
state the implemented scope, name a source and light SVG, and optionally provide
a dark SVG, a qualified player and companion artifacts. BPMN players illustrate
structure or supplied scenarios; regex and EBNF evidence comes from external
engines. General PlantUML diagrams, Draw.io and DOT remain planned.

```shell
mise run gallery -- --site-assets
mise run validate:examples
mise run test:animation
mise run test:site-consumer
mise run test:site -- --tree next
```

The exporter owns `site/gallery.json` and `apps/site/assets/examples/`. Telescope
validates and renders that version 1 contract. Do not edit Telescope internals to
add an example. `consumer/gallery_wbtest.mbt` demonstrates adding a fixture
through this contract and rejects duplicate IDs, missing files, traversal and
symlinks escaping the artifact root. Provider tests cover real native rendering.
The browser suite covers gallery previews, downloads, scope labels, themes,
keyboard navigation, narrow widths and reading without JavaScript.

The reviewed compatibility inventory is `fixtures/compatibility/routes.json`.
Run `mise run check:site-compatibility -- --out _site/next` for a selected tree.
Do not recapture the baseline to accept removed routes or anchors.
