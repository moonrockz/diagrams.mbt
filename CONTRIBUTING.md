# Contributing to diagrams.mbt

Read [the README](README.md) first to set up the toolchain. This guide tells you how
to plan a change, track it, and get it ready for review.

## How work moves

1. Write or update an OpenSpec change. It holds the requirements and the design.
2. Track the implementation in beads (`bd`). Each task group in the change has one bead.
3. Implement one bead at a time. Tick its tasks in the change.
4. Run the checks and open a pull request. The pull request that lands the last
   task group also archives the change.
5. After the merge, close the beads and sync them. See [Land a change](#land-a-change).

A typo fix, a dependency bump or a build-only change does not need an OpenSpec change.
A change to public behavior, a public API or a requirement needs one.

## OpenSpec

[OpenSpec](https://github.com/Fission-AI/OpenSpec) is pinned in
`.config/mise/config.toml`. `mise install` installs it. Run it through mise:

```shell
mise exec -- openspec list                  # changes in progress
mise exec -- openspec list --specs          # accepted specifications
mise exec -- openspec show <change>         # one change
mise exec -- openspec view                  # interactive dashboard
mise exec -- openspec validate --all --strict
```

The files are in `openspec/`:

| Path | Contents |
| --- | --- |
| `openspec/config.yaml` | Project context and rules that every change follows |
| `openspec/specs/<capability>/spec.md` | Accepted requirements, one folder for each capability |
| `openspec/changes/<change>/` | A change in progress |
| `openspec/changes/archive/` | Changes that are complete |

A change folder has these files:

| File | Contents |
| --- | --- |
| `proposal.md` | Why the change is necessary, what it changes, and what is out of scope |
| `design.html` | How the change works. Each decision has a label: "Owner" for a maintainer decision, or "Call" for a decision of the author |
| `specs/<capability>/spec.md` | Requirement changes under `## ADDED`, `## MODIFIED` or `## REMOVED Requirements` headings. Each `### Requirement:` uses SHALL or MUST and has one or more `#### Scenario:` blocks with **WHEN** and **THEN** lines |
| `tasks.md` | Task groups. Each group is one story and has a `Bead:` line with its beads ID |

### HTML design documents

New changes use the local `html-design` schema. Start a design from
`.agents/templates/agent-document.html` and keep its local styles and scripts.
Use `../../../.agents/templates/assets/` from an active change and
`../../../../.agents/templates/assets/` from an archived change. Check these links
when archiving. Existing changes retain their declared schema and `design.md`.
Templates live under `.agents/` because the current site publishes HTML files
below `docs/`; the design template is development tooling, not a docs page.

The schema and document template come from `finos/morphir-moonbit` at
`bd3adc52e6b8f6368fdaee50f76535799732f8d6`, under Apache-2.0.
The copied highlight.js assets retain their BSD license and upstream record in
`.agents/templates/assets/highlight/`. Repository tracker and landing rules take
precedence over the source project's rules.

### Write a change

Use kebab-case names that start with a verb, for example `add-configuration-core`.

The repository includes OpenSpec entry points for Codex, Claude Code, Grok Build,
Cursor and GitHub Copilot. Muse uses the portable workflow in `AGENTS.md` and the
shared skills in `.agents/skills/`. All agents use the same specifications,
project configuration and beads tracker.

| Workflow | Shared skill name | Purpose |
| --- | --- | --- |
| explore | `openspec-explore` | Examine an idea before writing a change |
| propose | `openspec-propose` | Create a change and its planning artifacts |
| update | `openspec-update-change` | Revise an existing change |
| apply | `openspec-apply-change` | Implement tasks |
| sync | `openspec-sync-specs` | Copy requirement changes into accepted specifications |
| archive | `openspec-archive-change` | Archive a complete change |

Use the invocation syntax of your agent. These examples select the apply workflow;
substitute the workflow or skill name from the table above.

| Agent | Installed skills | Invocation |
| --- | --- | --- |
| Codex CLI / IDE | `.agents/skills/` | `$openspec-apply-change <change>` |
| Codex desktop | `.agents/skills/` | Select `openspec-apply-change` from Skills in the sidebar |
| Claude Code | `.claude/skills/` | `/opsx:apply <change>` or `/openspec-apply-change <change>` |
| Grok Build | `.grok/skills/` | `/openspec-apply-change <change>` |
| Cursor | `.cursor/skills/` | `/opsx-apply <change>` |
| GitHub Copilot | `.github/skills/` | `/opsx-apply <change>` |
| Muse / portable agents | `.agents/skills/` | Ask it to read the matching `SKILL.md` and follow it for `<change>` |

If skill discovery is unavailable, use this prompt with any agent:

> Read AGENTS.md, CONTRIBUTING.md and
> .agents/skills/openspec-apply-change/SKILL.md. Follow that workflow to implement
> change `<change>`, including its beads and verification steps.

The paths and invocation syntax follow the
[OpenSpec tool matrix](https://openspec.dev/docs/supported-tools). Codex discovers
repository skills in `.agents/skills/`, as described in the
[official OpenAI documentation](https://learn.chatgpt.com/docs/build-skills).
Muse has no built-in OpenSpec adapter; its portable entry point does not require
a particular Muse client or slash-command system.

### Refresh agent integrations

After changing the pinned OpenSpec version, or to restore missing entry points, run:

```shell
mise run openspec:setup
mise exec -- openspec validate --all --strict
```

The setup task installs the six core workflows as skills for all five supported
clients, plus commands for Claude, Cursor and Copilot. It uses temporary OpenSpec
settings with `profile: core` and `delivery: both`; your machine-wide profile and
delivery settings stay unchanged. It preserves `openspec/config.yaml`, existing
specifications and changes. Review and commit the generated files with the setup
task. Keep repository-specific instructions in `AGENTS.md`, `CONTRIBUTING.md` and
`openspec/config.yaml`, rather than editing generated skills or commands.

Restart or reload the agent if the new entry points do not appear. In Codex CLI
or the IDE extension, check `/skills` or type `$openspec-` to select a workflow.
In Codex desktop, check Skills in the sidebar. With a portable client, explicitly
load `AGENTS.md` at the start of the session.

The task configures Copilot skills and editor prompts. GitHub-hosted Copilot
environment setup is separate; it is not installed by this task.

### Claude command reference

Claude Code also provides the following commands:

| Command | Use |
| --- | --- |
| `/opsx:explore` | Examine an idea or a problem before you write a change |
| `/opsx:propose` | Make a change and write all of its files |
| `/opsx:update` | Revise the files of a change and keep them consistent |
| `/opsx:apply` | Implement the tasks of a change |
| `/opsx:sync` | Copy the requirement changes into `openspec/specs/` without archiving |
| `/opsx:archive` | Archive a complete change |

Without an agent, run `mise exec -- openspec new change <name>`. Then run
`mise exec -- openspec instructions <artifact> --change <name>` to see the template
and the rules for each file.

Follow these rules:

- Write in ASD-STE100 Simplified Technical English.
- Make each scenario specific enough that a test can check it.
- Put the first task group as a tracer bullet: a thin path through the full change.
  If a decision depends on something nobody has tried yet, make the first group a
  spike that tries it.
- Do not put the content of `openspec/config.yaml` into the change files.
- Run `mise exec -- openspec validate <change> --strict` before you ask for review.

### Track the work in beads

After a maintainer approves the change, make one bead for each task group. Put the
beads under one epic for the change, and write each ID on the `Bead:` line of its group.
Add a dependency between beads when one group needs the result of another.

```shell
bd ready                     # beads with no open blockers
bd show <id>                 # one bead and its dependencies
bd update <id> --claim       # start work on a bead
bd close <id>                # after its tasks are done and verified
```

### Implement a task group

1. Claim a bead. Do the tasks of its group, then tick each one in `tasks.md` (`- [x]`).
2. Run `mise run format` and `mise run check`.

### Land a change

A pull request is not landed until the specification and the beads show its result.
Do these steps for each pull request, also for a bug fix that a bead tracks.

In the pull request:

1. Tick the tasks of each group that the pull request completes.
2. If no open task stays in the change after this pull request, archive the change
   in the same pull request: `mise exec -- openspec archive <change> --yes`. This
   moves the change to `openspec/changes/archive/` and merges its requirement
   changes into `openspec/specs/`. Update the links that point to the old folder.
3. Run `mise exec -- openspec validate --all --strict`, `mise run format` and
   `mise run check`.
4. In the description, name each bead that the pull request completes.

After the merge:

1. Close each bead that the pull request completes. Give the pull request and the
   merge commit as the reason:
   `bd close <id> --reason "Landed in #<pr> (<sha>)"`.
2. If all the child beads of an epic are closed, point the epic to the archived
   change and close it:
   `bd update <epic> --spec-id openspec/changes/archive/<folder>`, then
   `bd close <epic> --reason "All stories landed; change archived in #<pr> (<sha>)"`.
3. Run `bd dolt pull`, then `bd dolt push`. Make sure that the push succeeds.
4. Delete the branch.

Do not close a bead before its pull request merges. Do not close an epic while it has
an open child bead, for example a bug that a review found.

## Releases

Releases run only in GitHub Actions (`.github/workflows/release.yml`, adapted
from [Smithy's release flow](https://github.com/moonrockz/smithy/blob/main/.github/workflows/release.yml)).
Ask the owner before opening or merging a release pull request; merging it is
the publication approval. The pull request sets the shared version with
`scripts/versions.mbtx set X.Y.Z` and adds the `## X.Y.Z` section to
`CHANGELOG.md`, and the workflow dry-runs its checks on it. After the merge the
workflow runs `mise run check`, publishes `pkgs/diagrams`
with the `MOONCAKES_USER_TOKEN` organization secret (an existing version counts
as published), and then creates the GitHub release `vX.Y.Z`.
Repository access to that secret must be verified before the first run.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/), for example
  `feat(mermaid): add the flowchart parser` or `docs(openspec): propose add-diagram-model`.
- Do not add AI attribution lines to commits, pull requests or issues.
- Install the hooks with `mise run hooks:install`. Pre-commit checks formatting,
  compiler warnings and generated interfaces of the staged files. These checks read the
  working tree, so pre-commit first fails when a MoonBit file (`.mbt`, `.mbt.md`,
  `.mbti`, `.mbtx` or a `moon.*` manifest) is untracked, has unstaged changes, or is
  ignored by git but still read by moon. Build and dependency output in `_build/` and
  `.mooncakes/` does not count. Stage those changes, or set them aside, and commit again. Pre-push runs lint, workspace
  validation and tests.
- Commit the `pkg.generated.mbti` file of each package, as MoonBit convention
  recommends. `mise run lint` writes these files and fails when one is new or changed
  and not staged. Review the interface change, stage the file, and run lint again.
  Moon writes an interface only from a module's canonical backend, so a package that
  cannot build on that backend has no interface.
- CI must pass. The `ci-ok` job is the aggregate check.
