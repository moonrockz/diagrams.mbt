# diagram-gallery Specification

## Purpose
Let readers inspect the library's implemented diagram capabilities through qualified examples with visible sources, static previews and optional offline interaction.

## Requirements

### Requirement: Gallery entry and example routes

The site SHALL provide `/gallery/` and a stable detail URL for each example.
Readers SHALL be able to find examples by diagram family and follow links
from the landing page and primary navigation. Flowchart examples SHALL
identify their Mermaid or PlantUML source format and PlantUML dialect.

#### Scenario: Find a diagram family

- **WHEN** a reader opens the gallery from the landing page
- **THEN** the reader can find sequence, ZenUML, architecture, BPMN, swimlane, regex, EBNF, JSON, YAML and flowchart examples
- **AND** every listed example links to its own stable page

### Requirement: Source and static preview

Each example SHALL identify its diagram family, format, title and supported scope. Its page SHALL show or link to the exact source and a script-free SVG preview, with usable source and SVG downloads.

#### Scenario: Inspect an example without JavaScript

- **WHEN** a reader opens an example page without JavaScript
- **THEN** the reader can inspect the source, see the preview and download the source and SVG

### Requirement: Qualified artifact inputs

The site build MUST consume examples produced by the repository's checked diagram pipeline. It MUST reject duplicate example IDs, missing sources, missing previews and paths outside the allowed input root.

#### Scenario: Missing preview

- **WHEN** a gallery entry names a missing preview
- **THEN** the build fails with the example ID and artifact path

#### Scenario: Invalid example identity or path

- **WHEN** two entries share an ID or an entry escapes its allowed artifact directory
- **THEN** the build fails before publishing the gallery

### Requirement: Optional offline players

An example with a qualified offline player SHALL link to that player. Example pages without players MUST remain complete. Players MUST preserve their documented playback, bounded exploration and trace evidence limits.

#### Scenario: Open an animated example

- **WHEN** a reader opens an available player from its example page
- **THEN** the player works with the supplied assets and no external service
- **AND** the page states whether it shows structural illustration, exploration or externally supplied trace evidence

### Requirement: Honest support descriptions

Gallery labels MUST distinguish implemented formats and views from planned behavior. BPMN playback MUST be described as illustration of structure or explicit scenarios. Regex and EBNF evidence MUST be described as supplied by an external engine.

#### Scenario: Read semantic limits

- **WHEN** a reader opens a BPMN, regex or EBNF example
- **THEN** the page does not claim BPMN token simulation or execution
- **AND** any regex or EBNF execution evidence identifies its external provider

### Requirement: Themes and version context

Gallery links and assets SHALL use the active base path and version tree. Previews SHALL remain readable in light and dark themes, and player controls SHALL retain keyboard and reduced-motion behavior.

#### Scenario: Gallery in next docs

- **WHEN** a reader visits `/diagrams.mbt/next/gallery/` at a narrow viewport in either theme
- **THEN** detail, source, preview and player links resolve in that tree
- **AND** the content remains readable without clipped controls

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

### Requirement: Qualified state diagram examples

The checked local and published galleries SHALL add a state family with at
least three distinct Mermaid sources and three distinct PlantUML sources.
Across the set, examples SHALL cover simple lifecycles, labelled transitions,
self-loops, composite states, concurrency, choice/fork/join and PlantUML history.
Theme, connector and playback variants SHALL NOT count as distinct sources.

#### Scenario: Browse state coverage

- **WHEN** a reader opens the state gallery family
- **THEN** at least six distinct sources are available, each labelled with its format and scope and linked to a stable detail page

### Requirement: State source previews and players

Each state example SHALL provide exact source, adaptive/light/dark script-free
SVG and a qualified offline player through the checked artifact pipeline.
Details SHALL offer existing preview/source controls, source copy/download and
SVG downloads. Labels SHALL describe structural playback and supplied scenarios
without claiming event processing, guard evaluation or history restoration.

#### Scenario: Inspect a history example

- **WHEN** a reader opens the PlantUML history example
- **THEN** source, themed SVG downloads and the offline player are available and the page states that history is descriptive rather than restored by execution

### Requirement: State guides and gallery compatibility

Guides SHALL describe pinned syntax profiles, refusals, model construction,
geometry, connector options, playback/query limits and exhaustive enum migration.
State pages SHALL obey versioned base paths, no-script/narrow browsing and both
themes. Existing IDs, family anchors, routes, source and static SVG bytes SHALL
remain unchanged. Shared player updates SHALL be qualified separately.

#### Scenario: Versioned no-script browsing

- **WHEN** root and next state pages open without JavaScript at 360 CSS pixels in either theme
- **THEN** preview, source, scope and downloads remain readable and all detail/asset/player links resolve in the selected version tree

#### Scenario: Existing gallery regression

- **WHEN** the checked gallery inventory and prior artifact digests are compared after state support
- **THEN** all existing examples retain their URLs, source and SVG bytes and any shared-player HTML changes match reviewed runtime snapshots
