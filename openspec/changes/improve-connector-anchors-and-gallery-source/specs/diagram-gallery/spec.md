# Spec Delta

## ADDED Requirements

### Requirement: Gallery card preview and source tabs

Each implemented gallery index card SHALL provide Preview and Source tabs.
Preview SHALL show its rendered image. Source SHALL show the exact declared
diagram text with format and filename, copy and download actions, and access to
each source when several files are declared. Controls SHALL act within that card.

#### Scenario: Inspect source in place

- **WHEN** a reader chooses Source on a gallery card
- **THEN** that card displays its original Mermaid, PlantUML, BPMN XML or other declared source as selectable text without navigating away
- **AND** the displayed text equals the corresponding source download

#### Scenario: Several sources and independent cards

- **WHEN** an example declares multiple source files or a reader selects Source on one of two cards
- **THEN** every declared file is available with its own filename and download
- **AND** the other card's selected tab and viewer state remain unchanged

### Requirement: Gallery tab accessibility and fallback

Tabs SHALL have accessible names, unique relationships, visible focus and
standard keyboard tab navigation. At narrow widths source SHALL scroll within
its own panel without page overflow. Without JavaScript, previews and original
sources SHALL remain reachable without inactive tab controls.

#### Scenario: Keyboard and narrow source view

- **WHEN** a keyboard reader switches tabs at 360 CSS pixels
- **THEN** focus and selected-tab state agree and long source lines scroll inside their panel
- **AND** all copy and download controls remain usable in light and dark themes

#### Scenario: No-script gallery reading

- **WHEN** scripting is disabled
- **THEN** a reader can inspect static previews and expand or follow the original source for each card
- **AND** no inactive tab control hides that content

#### Scenario: Hostile source and unavailable copy

- **WHEN** source contains script-like text or clipboard access is denied
- **THEN** source remains safely rendered as literal text, selectable and downloadable
- **AND** source content cannot execute or alter the page

### Requirement: Tab and viewport compatibility

Changing tabs SHALL preserve each preview's zoom, pan and source selection.
Returning to Preview SHALL leave fullscreen, Fit, raster download, gallery
filters and detail navigation usable. Existing detail-page tabs and all
versioned source and artifact URLs SHALL remain available.

#### Scenario: Return to the same view

- **WHEN** a reader zooms and pans, selects Source and returns to Preview
- **THEN** the previous viewport is restored and its controls still work
- **AND** family/text filters, card detail links and current version-tree URLs are unchanged

### Requirement: Local gallery source inspection

The generated local gallery SHALL provide Preview and Source inspection for
examples with declared original text. Theme variants SHALL refer to the same
source. Examples without declared source SHALL identify that absence instead
of inventing syntax from SVG. Local inspection SHALL work offline.

#### Scenario: Read a local example

- **WHEN** a reader opens the generated local gallery without network access and selects Source
- **THEN** available original text is shown with its filename and download, or the example explicitly identifies unavailable source
- **AND** the preview and existing exports remain usable

