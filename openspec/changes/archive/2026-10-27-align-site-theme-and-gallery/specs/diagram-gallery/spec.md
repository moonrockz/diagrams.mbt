## ADDED Requirements

### Requirement: Component-library gallery browsing

The gallery SHALL display the qualified examples as preview cards with title, family and support status. Readers SHALL be able to browse by family and, when scripting is enabled, filter by text with a result count and reset action. Available light and dark previews MUST remain readable and preserve complete diagram content.

#### Scenario: Browse the qualified example set

- **WHEN** a reader opens `/diagrams.mbt/next/gallery/` in either theme
- **THEN** the gallery provides all 12 existing examples across nine families as visual cards
- **AND** each card links to its existing stable detail route
- **AND** family navigation and cards remain usable without JavaScript

#### Scenario: Filter and clear

- **WHEN** a reader combines a family selection with text that matches no example
- **THEN** the gallery reports zero results and offers a reset action
- **AND** clearing the filters restores all 12 cards without a remote request

### Requirement: Example preview and source inspection

Example details SHALL place the rendered preview in a prominent bounded panel and provide Preview and Source controls, visible scope information, source copy and download actions, and supplied SVG downloads. Existing optional offline players SHALL remain separate working links. All source and preview artifacts MUST retain their bytes and existing URLs.

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
- **THEN** the existing detail URLs, family anchors and all 40 gallery artifact files resolve with unchanged artifact bytes
- **AND** BPMN, regex and EBNF scope labels retain their existing execution and evidence limits
