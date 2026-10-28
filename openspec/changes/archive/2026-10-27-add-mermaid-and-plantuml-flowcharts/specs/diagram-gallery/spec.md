# Spec Delta

## MODIFIED Requirements

### Requirement: Gallery entry and example routes

The site SHALL provide `/gallery/` and a stable detail URL for each example.
Readers SHALL be able to find examples by diagram family and follow links
from the landing page and primary navigation. Flowchart examples SHALL
identify their Mermaid or PlantUML source format and PlantUML dialect.

#### Scenario: Find a diagram family

- **WHEN** a reader opens the gallery from the landing page
- **THEN** the reader can find sequence, ZenUML, architecture, BPMN, swimlane, regex, EBNF, JSON, YAML and flowchart examples
- **AND** every listed example links to its own stable page

### Requirement: Component-library gallery browsing

The gallery SHALL display qualified examples as preview cards with title,
family and support status. Readers SHALL be able to browse by family and,
when scripting is enabled, filter by text with a result count and reset
action. Light and dark previews MUST remain readable and preserve complete
diagram content. Counts and filter results SHALL use the qualified example set.

#### Scenario: Browse the qualified example set

- **WHEN** a reader opens `/diagrams.mbt/next/gallery/` in either theme
- **THEN** the gallery provides all qualified examples, including the 12 existing examples across nine families and the added flowchart examples, as visual cards
- **AND** each existing card retains its stable detail route and each added card has a stable detail route
- **AND** family navigation and cards remain usable without JavaScript

#### Scenario: Filter and clear

- **WHEN** a reader combines a family selection with text that matches no example
- **THEN** the gallery reports zero results and offers a reset action
- **AND** clearing the filters restores the complete qualified card set without a remote request

## ADDED Requirements

### Requirement: Qualified flowchart examples and guides

The checked gallery pipeline SHALL provide source, adaptive/fixed-theme SVG
and offline players for Mermaid flowcharts and both PlantUML activity dialects.
Examples SHALL include branching, a loop, parallel paths and nested ownership
across the set. Guides SHALL state pinned syntax profiles, refusals, enum
migration and structural playback limits. Existing URLs and artifact bytes
SHALL remain unchanged except qualified shared-player runtime updates.

#### Scenario: Inspect all flowchart source forms

- **WHEN** a reader opens the flowchart gallery family
- **THEN** at least one Mermaid, one modern PlantUML and one legacy PlantUML example has exact source, SVG downloads and a qualified offline player
- **AND** labels explain that routes and playback do not evaluate conditions or execute the workflow

#### Scenario: Versioned and no-script browsing

- **WHEN** the site is checked under root and next base paths at a narrow viewport without JavaScript
- **THEN** flowchart detail, source, preview and player links resolve in their version tree, both themes remain readable and all existing gallery routes still work
