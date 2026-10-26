# Proposal

## Why

The project site repeats a MoonBit and Rabbita site generator that also exists in Smithy and Morphir. Use a released Telescope package to share that work, and give readers a landing page, documentation and a gallery that shows the diagram capabilities this library implements.

## What Changes

- Replace the copied site engine in `apps/site` with a small consumer of a released `moonrockz/telescope` library and CLI. Pin real published versions before migration lands.
- Update the landing page to explain the current library and link to documentation and the gallery.
- Add `/gallery/` with stable example pages, source downloads, SVG previews and optional offline players. Keep diagram generation and qualification in this repository.
- Keep existing documentation, package READMEs, API pages, articles, search, theme controls and version trees working at `/diagrams.mbt/`.
- Keep the published diagram libraries free of UI dependencies. Telescope and Rabbita remain dependencies of the unpublished site tool only.
- Use the local HTML design schema for this change and new changes. Existing change schemas stay intact.

## Capabilities

### New Capabilities

- `project-site`: Landing, docs, API and versioned site behavior built with a released site toolkit. No accepted site capability exists in the current specification inventory.
- `diagram-gallery`: Browsable examples with checked sources, previews and offline players, with support status that matches implemented behavior.

### Modified Capabilities

None. Library parsing, rendering, animation and trace semantics stay under their existing specifications.

## Beads

Tracked by epic `diagrams-3dz`. The owner approved implementation with gallery digests removed. Each numbered task group has one story. The migration depends on Telescope change `extract-project-site-toolkit` in `moonrockz/telescope`, including its owner-approved release.

## Impact

`apps/site`, `site/site.json`, `site/pages`, gallery metadata and assets, `scripts/site.mbtx`, gallery export integration, site tests and the site build workflows. Shared engine fixes move to Telescope. The current site and build commands are the compatibility baseline.

The Telescope repository is `https://github.com/moonrockz/telescope`. Development is in its Orca `telescope-foundation` workspace; the shared coordination Run is `run_b3638d9bfa3d` and its coordinator mailbox is `run:run_b3638d9bfa3d`.

Out of scope: migrating Smithy or Morphir in this change, adding diagram formats, executing BPMN, a CMS, a general plugin marketplace, and releasing or publishing any package without owner approval.
