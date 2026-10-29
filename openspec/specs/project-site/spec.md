# project-site Specification

## Purpose
Give readers a project landing page and documentation site that uses a released shared toolkit and retains the project's existing public links.

## Requirements

### Requirement: Released toolkit dependency

The site build MUST use explicit published Telescope versions. A fresh checkout MUST build without a sibling Telescope checkout or an unpublished workspace dependency.

#### Scenario: Independent consumer build

- **WHEN** a fresh checkout installs the pinned dependencies and builds the site
- **THEN** the build uses published Telescope artifacts and succeeds without a Telescope source checkout

### Requirement: Project landing page

The site SHALL provide a landing page at its configured root with links to documentation, the gallery and the source repository. It SHALL describe the implemented diagram capabilities and identify planned formats as planned.

#### Scenario: Reader enters the project site

- **WHEN** a reader opens `/diagrams.mbt/`
- **THEN** the page explains the library and links to working docs and gallery pages below that base path
- **AND** general PlantUML diagrams, Draw.io and DOT are not presented as implemented

### Requirement: Documentation compatibility

The site SHALL retain the routes and heading anchors of existing published docs, package READMEs and API pages. Source links SHALL resolve to the correct repository revision.

#### Scenario: Existing deep link

- **WHEN** a reader opens a pre-migration docs or API URL with a heading anchor
- **THEN** the corresponding content and anchor exist at that URL

### Requirement: Site reading controls

The site SHALL retain navigation, search, light and dark themes, code-copy controls and mobile navigation. Core content and links MUST remain usable without JavaScript. Controls MUST support keyboard use, and motion MUST respect reduced-motion preferences.

#### Scenario: Keyboard and no-script reading

- **WHEN** a reader disables JavaScript or uses keyboard navigation at a narrow viewport
- **THEN** the core page content and links remain available
- **AND** enabled interactive controls have accessible names and visible focus

### Requirement: Versioned output compatibility

The site SHALL preserve the existing next, minor-release, root and latest trees, version metadata, banners and canonical links. Links within a tree MUST remain in that tree except for explicit version navigation and canonical links.

#### Scenario: Assemble current and historical docs

- **WHEN** the build assembles next output with available historical release site assets
- **THEN** `/diagrams.mbt/next/`, `/diagrams.mbt/v/<minor>/`, the root and `/diagrams.mbt/latest/` retain their current roles
- **AND** tree-aware link checks pass without rebuilding historical releases with Telescope

### Requirement: Site publication boundary

The published diagram libraries MUST remain independent of Telescope, Rabbita and browser UI packages. Site content MUST exclude local design and implementation plans under `docs/superpowers/`.

#### Scenario: Published library consumer

- **WHEN** a consumer installs the diagram libraries for wasm, wasm-gc, js or native
- **THEN** that consumer needs no site toolkit or UI dependency

#### Scenario: Local plan exclusion

- **WHEN** a site build scans documentation sources
- **THEN** no file under `docs/superpowers/` appears in the output or search index

### Requirement: Checked site build

The documented build, check, test and preview commands SHALL remain available. Builds MUST fail with source-specific diagnostics for invalid content, missing required assets, duplicate routes or broken internal links.

#### Scenario: Broken documentation input

- **WHEN** a required page or asset is missing, or two pages claim one route
- **THEN** the build or check exits nonzero and identifies the source and problem

### Requirement: Smithy-aligned shared site colors

The diagrams.mbt site SHALL inherit the Smithy-aligned default palette from an explicitly published Telescope library and matching CLI release. Landing, docs, API and gallery pages SHALL use a consistent palette in light, dark and system modes. The consumer MUST NOT duplicate shared theme rules to obtain this result.

#### Scenario: Shared palette in a fresh checkout

- **WHEN** a fresh checkout builds the next site using its published Telescope pins
- **THEN** light mode uses background `#f9fafb`, surface `#ffffff`, text `#111827` and accent `#4f46e5`
- **AND** dark mode uses background `#0f1014`, surface `#17181f`, text `#e5e7eb` and accent `#a5b4fc`
- **AND** the site needs no sibling checkout, unpublished dependency or duplicated theme stylesheet

#### Scenario: Consistent reading controls

- **WHEN** a reader switches themes while visiting landing, documentation, API and gallery pages
- **THEN** links, selected navigation, search, code controls and gallery panels remain readable with visible keyboard focus
- **AND** system fallback, stored preferences and reading without JavaScript retain their existing behavior

#### Scenario: Preserve versioned release presentation

- **WHEN** the new next site is assembled with historical release site assets
- **THEN** the new shared presentation applies to the new build under `/diagrams.mbt/next/`
- **AND** historical release assets retain their bytes and the root, latest and minor-version trees retain their accepted roles

### Requirement: Moonrockz project branding

The current site SHALL use the selected Lunar drafter badge on its landing page
and the matching bunny-and-pencil icon in its header and favicon assets.
Branding alternative B and C originals and generation prompts SHALL remain
available in the repository. Site asset URLs SHALL follow the active base path
and version tree.

#### Scenario: Open the branded site

- **WHEN** a reader opens the current root or next landing page
- **THEN** the selected A badge, header icon and favicon load without broken links
- **AND** the original B and C images remain in the brand asset directory

### Requirement: Landing page presentation

The landing page SHALL provide a prominent branded introduction, clear links to
getting started, docs, API and gallery, and visual examples of supported diagram
families. Content SHALL distinguish implemented capabilities from planned work
and retain existing semantic limits and heading anchors.

#### Scenario: Browse from the landing page

- **WHEN** a reader opens the page at 360, 768 or 1440 CSS pixels in either theme
- **THEN** the introduction, primary links and examples remain readable without clipped content
- **AND** every primary link resolves within the active version tree unless it explicitly leaves the site
