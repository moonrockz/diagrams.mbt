# Proposal

## Why

Readers need to inspect large diagrams without leaving the gallery. The site and
offline player also need a clear, consistent presentation that uses the selected
Moonrockz branding.

## What Changes

- Use the selected A logo on a redesigned landing page and use the saved icon
  assets for the site header and favicon. Keep B and C as branding alternatives.
- Add top-right Fullscreen, Zoom in, Zoom out and Fit controls to rendered image
  panels in the published gallery and the generated local gallery.
- Let readers drag or use the keyboard to pan an enlarged diagram. Keep controls
  separate from card navigation, downloads and source inspection.
- Give the shared animation player a clear header, a large diagram stage, a
  primary playback action, a useful timeline and grouped exploration controls.
  Match the site palette in light, dark and system modes.
- Add the same viewport controls to the player, without changing logical playback.
- Add supported library conversion of diagrams.mbt-generated SVG to PNG and JPEG,
  plus deterministic animated GIF export from a source-bound playback plan.
  Return encoded binary data through a typed result. Keep the existing text
  renderer API compatible.
- Offer PNG as the default raster download, JPEG as another still format, and
  animated GIF in the player. Let readers choose dimensions, background, JPEG
  quality, and bounded GIF timing and loop options.
- Document public styling hooks for the shared viewport and player: CSS custom
  properties, stable part classes and explicit theme scope.
- Keep offline use, accessible controls, reduced motion, no-script static
  previews, canonical SVG downloads and existing versioned routes.

## Capabilities

### New Capabilities

- `diagram-viewer-controls`: Shared fullscreen, zoom, pan, fit and styling
  contracts for gallery image panels and animation stages.
- `diagram-raster-export`: Library conversion to PNG and JPEG, and animated
  GIF export from the library's generated scenes and playback plans.

### Modified Capabilities

- `diagram-gallery`: Image controls and PNG/JPEG downloads on published cards,
  detail pages and local gallery panels.
- `diagram-animation`: A themed player layout and shared viewport controls with
  host styling hooks and raster downloads.
- `project-site`: Selected branding on the landing page, site header and favicon.

## Out of Scope

- Diagram editing, new diagram syntax, execution or simulation.
- General-purpose conversion of arbitrary third-party SVG.
- New playback semantics or changes to graph queries.
- Rewriting static SVG or source bytes.
- Retheming historical release archives.
- Adding Telescope, Rabbita or a UI framework to a published diagram module.
- Cutting a release or publishing from a workstation.

## Beads

Approved for implementation. Epic `diagrams-87x` contains stories `diagrams-87x.1`
through `diagrams-87x.7`, one per numbered task group.

## Impact

- `site/pages/index.html`, `site/site.json`, `docs/assets/brand/` and the
  published Telescope pins in the consumer and CLI wrapper.
- Shared Telescope gallery markup, browser behavior, styles and branding support.
  These live in the Telescope repository and must ship in a published release
  before this repository adopts them. No sibling path dependency or generated
  HTML patch is part of the production solution.
- `scripts/gallery.mbtx`, `pkgs/diagrams-animated/html.mbt`,
  `pkgs/diagrams-animated/assets/` and their generated assets and snapshots.
- A first-class optional raster library under `pkgs/`, portable raster and
  codec dependencies, explicit font inputs, new binary results, and raster
  acceptance suites under `tests/`. No browser or external process is required
  by the library conversion API.
- Gallery, animation and site browser checks, offline qualification and all four
  MoonBit targets.

