# OpenSpec

## Shared OpenSpec bundle

`html-design` comes from Mission Control's shared bundle. The pinned
`mission-control-tools` CLI (`github:moonrockz/mission-control` in
`.config/mise/config.toml`) installs it and checks it. The schema, templates and
licenses are generated snapshots, and `openspec/extensions.lock.json` holds their
digests and the tool version. Keep repository overrides in `openspec/config.yaml`
and `AGENTS.md`.

- Run `mise run openspec:check` to compare the committed files with the lock and with
  the pinned CLI (`mission-control-tools openspec check --bundle`). CI runs this check.
- Run `mise run openspec:setup` to regenerate the six core agent skills with isolated global preferences.
- Run `mise run openspec:validate` (the schema and `openspec validate --all --strict`)
  before review, or `mise run openspec:verify` for the check and the validation.
- New designs are offline `design.html` with inline CSS. Existing changes keep
  their schema metadata and original designs, including Markdown designs.
- OpenSpec requirements and change artifacts are committed project documentation.
  Scratch documents remain local under the existing repository rules.

To update the snapshots, change the `version` of the mise entry, run `mise install`,
then:

```shell
mise exec -- mission-control-tools openspec install
mise run openspec:verify
```

Commit the mise file, the lock and the changed snapshot files. See
[the tools guide](https://github.com/moonrockz/mission-control/blob/main/apps/tools/README.md).
