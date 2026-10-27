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
