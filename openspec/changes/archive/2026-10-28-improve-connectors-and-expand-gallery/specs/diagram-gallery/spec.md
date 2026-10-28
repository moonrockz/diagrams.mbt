# Spec Delta

## MODIFIED Requirements

### Requirement: Component-library gallery browsing

The gallery SHALL display qualified examples as preview cards with title,
family and support status. Readers SHALL be able to browse by family and,
when scripting is enabled, filter by text with a result count and reset
action. Light and dark previews MUST remain readable and preserve complete
diagram content. Counts and filter results SHALL use the qualified example set.

#### Scenario: Browse the qualified example set

- **WHEN** a reader opens `/diagrams.mbt/next/gallery/` in either theme
- **THEN** the gallery provides all qualified examples, including all 15 existing cards and at least 30 additional distinct source examples across the ten supported families, as visual cards
- **AND** each existing card retains its stable detail route and each added card has a stable detail route
- **AND** family navigation and cards remain usable without JavaScript

#### Scenario: Filter and clear

- **WHEN** a reader combines a family selection with text that matches no example
- **THEN** the gallery reports zero results and offers a reset action
- **AND** clearing the filters restores the complete qualified card set without a remote request

### Requirement: Example preview and source inspection

Example details SHALL place the rendered preview in a prominent bounded panel and provide Preview and Source controls, visible scope information, source copy and download actions, and supplied SVG downloads. Existing optional offline players SHALL remain separate working links. Source artifacts MUST retain their bytes and existing URLs. Preview URLs MUST
remain stable; connector-related preview changes SHALL use reviewed qualified
artifacts under the connector-rendering contract.

#### Scenario: Inspect an implemented example

- **WHEN** a reader opens an existing example page and chooses Source
- **THEN** the page shows its exact source text and offers copy and download actions
- **AND** the reader can return to the preview, download supplied SVG variants and open any available offline player
- **AND** the page preserves its support and semantic limits

#### Scenario: Narrow viewport without scripting

- **WHEN** the reader opens an example with JavaScript disabled at 360 CSS pixels
- **THEN** preview, source text, scope and downloads remain available
- **AND** controls do not overflow the page and source code can scroll within its own panel

#### Scenario: Version and renderer compatibility

- **WHEN** the site is checked under the configured root and next base paths
- **THEN** the existing detail URLs, family anchors and all existing gallery artifact URLs resolve, source bytes remain unchanged, and connector-related SVG and HTML updates match reviewed qualified artifacts
- **AND** BPMN, regex and EBNF scope labels retain their existing execution and evidence limits

### Requirement: Qualified flowchart examples and guides

The checked gallery pipeline SHALL provide source, adaptive/fixed-theme SVG
and offline players for Mermaid flowcharts and both PlantUML activity dialects.
Examples SHALL include branching, a loop, parallel paths and nested ownership
across the set. Guides SHALL state pinned syntax profiles, refusals, enum
migration and structural playback limits. Existing URLs and artifact bytes
SHALL remain unchanged except qualified shared-player runtime and reviewed
connector-rendering updates.

#### Scenario: Inspect all flowchart source forms

- **WHEN** a reader opens the flowchart gallery family
- **THEN** at least one Mermaid, one modern PlantUML and one legacy PlantUML example has exact source, SVG downloads and a qualified offline player
- **AND** labels explain that routes and playback do not evaluate conditions or execute the workflow

#### Scenario: Versioned and no-script browsing

- **WHEN** the site is checked under root and next base paths at a narrow viewport without JavaScript
- **THEN** flowchart detail, source, preview and player links resolve in their version tree, both themes remain readable and all existing gallery routes still work
## ADDED Requirements

### Requirement: More distinct examples for every family

The published and local galleries SHALL add at least three distinct source
examples to each supported family: sequence, ZenUML, architecture, BPMN,
swimlane, flowchart, regex, EBNF, JSON and YAML. The added flowcharts SHALL include
Mermaid, modern PlantUML and legacy PlantUML. Theme, player and trace variants
of one source SHALL NOT count as additional source examples.

#### Scenario: Check family coverage

- **WHEN** the qualified gallery inventory is compared with the existing 15-card baseline
- **THEN** each of the ten families has at least three additional distinct sources and the gallery has at least 45 cards
- **AND** all previous IDs, detail URLs and family anchors still resolve

#### Scenario: Examples cover different structures

- **WHEN** a reader browses the additional examples of one family
- **THEN** they show different supported structures or use cases, rather than label-only copies
- **AND** the set includes small, nested and dense cases appropriate to that family

### Requirement: Visible connector option comparisons

The gallery SHALL show elbow, rounded-elbow and smooth-curve output, default
bridges and plain crossings, and readable marked endpoint approaches. Each
comparison SHALL identify its source and render options. Added examples SHALL
have qualified fixed light and dark previews, source downloads and offline
players where their model supports playback.

#### Scenario: Compare the same graph

- **WHEN** a reader opens a connector comparison example
- **THEN** the same graph is available in all three styles with bridges enabled and plain crossings available for comparison
- **AND** a reader can identify the options needed to reproduce each output

#### Scenario: Qualify the expanded gallery

- **WHEN** gallery generation, versioned site links and offline browser checks run
- **THEN** all added sources, previews, players and downloads resolve in root and next trees
- **AND** both themes, narrow viewports and no-script source/preview browsing remain usable
