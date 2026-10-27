# Proposal

## Why

The diagrams.mbt site should share Smithy's indigo and cool gray colors. Readers should browse diagram examples as visual specimens with easy access to source, as they do in component library galleries.

## What Changes

- Adopt the actual published Telescope release that supplies the Smithy-aligned default palette and shared gallery presentation.
- Use a preview card grid, family navigation and local filtering for the existing 12 examples across nine families.
- Present each example with a large preview, accessible Preview and Source controls, source copy and download actions, and its existing optional offline player link.
- Check the landing page, documentation, API and gallery together in light, dark and system themes, at wide and narrow viewports.
- Preserve current example IDs, URLs, source and SVG bytes, semantic scope statements, version trees and historical release assets.

## Capabilities

### New Capabilities

None. Extend the existing site and gallery contracts.

### Modified Capabilities

- `project-site`: inherit Smithy-aligned colors through the released shared toolkit.
- `diagram-gallery`: preview-first browsing and source inspection of the qualified example set.

## Beads

Tracked by epic `diagrams-cgy`; numbered task groups have repository-local stories.

Related change: Telescope `align-default-theme-and-gallery`. Adoption is blocked until a new library and matching CLI are actually published and independently verified. The current 0.1.1 pins stay in use until then.

## Impact

Published Telescope pins in `apps/site/moon.mod` and `scripts/telescope.mbtx`, consumer checks, browser acceptance tests and site documentation. The shared theme and gallery layout belong in Telescope. diagrams.mbt retains its content, diagram generation and support descriptions.

Out of scope: a project-specific copy of the gallery engine or CSS, changes to diagram renderer colors, new diagram families, live source editing, digest manifests, changes to historical release sites, and a diagrams library release. The new site continues to deploy to `/diagrams.mbt/next/` under the existing version policy.
