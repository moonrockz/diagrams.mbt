# diagrams.mbt

Read `README.md` for the workspace layout and commands. diagrams.mbt is a MoonBit
library for diagrams. It supports formats such as Mermaid, PlantUML, Draw.io and
Graphviz DOT. The library has no UI package.

## Working preferences

- Use compilers, linters, formatters, static analyzers, and focused tests for the
  issues they can determine. Reserve manual reasoning for behavior, requirements,
  architecture, performance, and concurrency.
- Keep `docs/superpowers/` design and implementation plans local. Never stage or
  commit them. Add that path to `.git/info/exclude` when needed, without changing
  the tracked `.gitignore`. Preserve local files if removing them from an unpushed
  commit.

## Planning and specifications

- Follow `CONTRIBUTING.md` for the OpenSpec and beads workflow. Changes to behavior,
  public APIs or requirements start as an OpenSpec change in `openspec/changes/`.
- New changes use the local `html-design` schema and `design.html`, based on
  `.agents/templates/agent-document.html`. Existing changes retain their declared
  schema and design artifacts. Update relative asset links when archiving HTML.
- Each task group in a change's `tasks.md` is one beads story; its `Bead:` line holds
  the ID. Tick the tasks in `tasks.md` in the pull request.
- Landing a pull request includes the tracker state. Follow "Land a change" in
  `CONTRIBUTING.md`: the last group's pull request archives the change; after the
  merge, close the beads with the PR and merge SHA, close a finished epic, and sync.
- Run `mise exec -- openspec validate --all --strict` after you edit `openspec/`.

### OpenSpec agent entry points

Run OpenSpec commands through `mise exec -- openspec` from the repository root.
Read `openspec/config.yaml` and the relevant accepted specifications before
planning or implementing a change. Use the six installed workflows: explore,
propose, update, apply, sync and archive. `CONTRIBUTING.md` lists the entry points
for each agent and the required beads and landing steps. Its landing rules take
precedence over generic generated workflow instructions: close beads only after
merge, and archive the last task group in its pull request.

Codex and portable agents, including Muse, use `.agents/skills/openspec-*/SKILL.md`.
Claude, Grok, Cursor and Copilot also have client-specific generated entry points.
If a client cannot discover skills, read the matching shared `SKILL.md` explicitly
and follow it. For example, to implement a change, read
`.agents/skills/openspec-apply-change/SKILL.md`. No slash-command support is required.
Refresh the generated files with `mise run openspec:setup`; do not edit them by hand.

## Toolchain and tasks

- Pin tools in `.config/mise/config.toml`. Run `mise trust` and `mise install`.
- Write automation in `scripts/*.mbtx`, run with `moonx`, and expose it as mise
  tasks. Pin imports. Do not replace these tasks with shell or PowerShell scripts.
- Use `moonbitlang/async` for process and filesystem operations. Propagate failures
  through nonzero exit codes.
- Put libraries under `pkgs/` and executables under `apps/`. Register modules in
  `moon.work`. Add acceptance suites under an unpublished `tests/` module when
  there is behavior to test.
- The root `moon.mod` is the version source of truth. Keep member versions and
  source version strings aligned using `scripts/versions.mbtx`.
- Prefer pure domain functions, explicit inputs, immutable public values, and
  typed alternatives. Keep I/O in host adapters and other boundary code.

## Verification

Run `mise run check` after changes. It runs lint, workspace and version validation,
tests for `wasm`, `wasm-gc`, `js`, and `native`, task script tests, and builds.
Run `mise run test:native-zig` when changing native toolchain integration.
Install Lefthook with `mise run hooks:install`. Run `mise run format` before
committing MoonBit changes. Commit the `pkg.generated.mbti` files that `mise run lint`
writes; lint fails when one is new or changed and not staged. Use Conventional Commits
without AI attribution.

## Publishing

The module name `moonrockz/diagrams` is provisional. Do not add UI packages. One
exception: the unpublished docs tool `apps/site` can use Rabbita. No other module
can import it, and the published library stays UI-free. Consume `zig-cross`
through `moonx`; do not vendor it. Ask before cutting a GitHub release or
publishing to mooncakes.io. Releases run only through
`.github/workflows/release.yml`, which publishes when an owner-approved version
change merges to `main`; never publish from a workstation.
