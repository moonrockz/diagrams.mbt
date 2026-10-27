# diagram-gallery Specification

## Purpose
Let readers inspect the library's implemented diagram capabilities through qualified examples with visible sources, static previews and optional offline interaction.

## Requirements

### Requirement: Gallery entry and example routes

The site SHALL provide `/gallery/` and a stable detail URL for each example. Readers SHALL be able to find examples by diagram family and follow links from the landing page and primary navigation.

#### Scenario: Find a diagram family

- **WHEN** a reader opens the gallery from the landing page
- **THEN** the reader can find sequence, ZenUML, architecture, BPMN, swimlane, regex, EBNF, JSON and YAML examples
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
