# diagrams.mbt

diagrams.mbt is a MoonBit library for diagrams. It reads Mermaid sequence
syntax and BPMN XML, renders script-free standalone SVG, and generates offline
HTML with illustrative flow playback and bounded structural exploration.
PlantUML, Draw.io and Graphviz DOT are planned. The library has no UI framework.

`moonrockz/bpmn` is an independent portable document reader, writer, validator
and reference/traversal module. It retains processes, collaborations,
choreography, conversations, diagram interchange and vendor extensions.
Rendering currently supports processes and collaborations; choreography and
conversation rendering is deferred. Playback describes drawn structure and
explicit scenarios. It does not execute BPMN or simulate tokens.

This project shares the setup, the design principles and the release pipelines of
the other moonrockz projects, such as
[moon-lander](https://github.com/moonrockz/moon-lander).

## Development setup

Install [mise](https://mise.jdx.dev/), then run:

```shell
mise trust
mise install
mise exec -- moon version --all
```

The MoonBit version is pinned in `.config/mise/config.toml`. The mise archive can
omit the core library and `moonx`. If the version check fails or `moonx` is missing,
complete that same installation with the official installer:

```shell
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | \
  MOON_HOME="$(mise where http:moonbit)" bash -s -- "$(mise current http:moonbit)"
```

Then install the hooks and check the workspace:

```shell
mise run hooks:install
mise run check
```

Pre-commit checks formatting and compiler warnings. Pre-push runs lint, workspace
validation, and tests. Local tool overrides belong in
`.config/mise/config.local.toml`, which is gitignored.

Work is tracked in [beads](https://github.com/steveyegge/beads) (`bd`).
Requirements and designs are OpenSpec changes in `openspec/`. See
[the contributing guide](CONTRIBUTING.md).

## Tasks

Tasks are MoonBit scripts under `scripts/`, run through `moonx` by mise.

| Command | Purpose |
| --- | --- |
| `mise run check` | Lint, validate, test the library and task scripts, and build |
| `mise run build` | Build `wasm`, `wasm-gc`, `js`, and `native` |
| `mise run test` | Test all four targets |
| `mise run test:bpmn-consumer` | Verify a fresh reader-only BPMN consumer on all four targets |
| `mise run test:animation` | Qualify stored offline BPMN/sequence players without a workspace/site rebuild |
| `mise run test:svg` | Check standalone SVG and adaptive themes in Chromium |
| `mise run gallery` | Verify the renderer snapshots and write sequence/BPMN views, XML and offline players to `_gallery/index.html` |
| `mise run build -- js --release` | Build a selected target in release mode |
| `mise run test -- native` | Test a selected target |
| `mise run format` | Format the workspace |
| `mise run lint` | Check YAML, MoonBit formatting, compiler warnings, and checked-in `pkg.generated.mbti` interfaces |
| `mise run validate` | Check workspace membership and shared versions |
| `mise run test:scripts` | Test the build tooling |
| `mise run build:site` | Build the docs site into `_site/` |
| `mise run dev:site` | Build the docs site, serve it at `http://127.0.0.1:4173/diagrams.mbt/` and build it again after a change |
| `mise run check:site` | Check the links of the built `_site/` |
| `mise run test:site` | Test the docs site packages and run the browser smoke test on the built site |
| `mise run test:native-zig` | Test native code using external `moonrockz/zig-cross@0.1.2` |
| `mise run clean` | Remove build artifacts |
| `mise run openspec:setup` | Refresh OpenSpec skills and commands for the supported agents |

## Layout

- `moon.mod` holds the shared version, currently `0.1.0`.
- `moon.work` lists the workspace members.
- `pkgs/bpmn/` is the independent BPMN document module, with MoonBit core dependencies only.
- `pkgs/diagrams-bpmn/` selects document views and adapts them to the shared BPMN model.
- `pkgs/diagrams-animated/` emits standalone HTML over pure motion plans and SVG scenes.
- `pkgs/diagrams/` contains the provisional `moonrockz/diagrams` library, imported
  as `@diagrams`, immutable sequence/BPMN models, motion/exploration and the renderer contract.
- `pkgs/diagrams-mermaid/` reads, prints and converts Mermaid sequence diagrams.
- `pkgs/diagrams-svg/` lays out sequence/BPMN models and writes standalone SVG and scene bindings.
- `tests/` contains the unpublished acceptance suites and frozen Mermaid/BPMN corpora.
- `apps/site/` is the unpublished docs site tool `moonrockz/diagrams-site`. It
  builds the static site at `https://moonrockz.github.io/diagrams.mbt/`.
- `docs/` and `site/` hold the content of the docs site.
- `openspec/` holds the requirements (`specs/`) and the changes in progress
  (`changes/`).
- `.beads/` holds the configuration of the beads issue tracker.
- `.config/mise/config.toml` pins the tools and declares tasks.
- `.github/workflows/` holds the CI, release and site workflows. The `ci-ok` job
  is the aggregate check for branch protection.

## Review the integrated output

Run `mise run gallery`, then open `_gallery/index.html`. It includes source XML,
supplied-DI and automatic BPMN views, fixed dark/light players and all 38 sequence
examples. After qualification, `mise run gallery -- --existing-output` regenerates
from stored snapshots without compiling. `--check` compares existing artifacts;
`--qualify` runs browser and link checks.
`--site-assets` also refreshes the selected examples used by the docs site.
Run `mise run test:animation` for offline player qualification.

Callers that exhaustively match the public `Diagram` enum must add its `Bpmn`
case. Existing sequence SVG bytes remain unchanged. See the tested module guides
and [BPMN and animation guide](docs/guides/bpmn-and-animation.md).

## Releases

Release versions are shared across workspace members. Releases run in GitHub
Actions, never from a workstation. See [the contributing guide](CONTRIBUTING.md).
