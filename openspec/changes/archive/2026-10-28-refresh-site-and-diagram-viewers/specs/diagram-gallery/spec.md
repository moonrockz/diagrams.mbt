# Spec Delta

## ADDED Requirements

### Requirement: Gallery raster downloads

Published gallery cards, example details and local image panels SHALL offer PNG
and JPEG downloads through the diagram-raster-export contract. PNG SHALL be the
default raster choice. Original SVG downloads SHALL remain available. Without
JavaScript, canonical SVG and source downloads SHALL remain usable.

#### Scenario: Save an example as PNG

- **WHEN** a reader selects a gallery image's PNG action
- **THEN** a complete raster of the canonical diagram downloads with a matching filename and media type
- **AND** zoom, pan, filtering and card navigation state are unchanged

#### Scenario: Choose JPEG

- **WHEN** a reader selects JPEG and an opaque background
- **THEN** the exported image uses that background and the chosen size and quality
- **AND** the original SVG action is still available

### Requirement: Gallery viewport controls

Rendered preview panels in published gallery cards, published example details
and the generated local gallery SHALL follow the diagram-viewer-controls
contract. Controls SHALL act on the visible preview and retain the active
theme, family filters, source inspection and stable detail links.

#### Scenario: Inspect a card without navigating

- **WHEN** a reader uses Zoom in or Fullscreen on a published gallery card
- **THEN** only that image changes view and the card detail route is not followed
- **AND** the card title still links to its detail page

#### Scenario: Inspect a detail or local preview

- **WHEN** a reader opens an example detail or the local gallery and enlarges a rendered image
- **THEN** the reader can zoom, pan, fit and exit fullscreen
- **AND** source and SVG links retain their existing targets

#### Scenario: Themes and version trees

- **WHEN** gallery controls are used at 360, 768 or 1440 CSS pixels in light or dark mode under root or next
- **THEN** controls remain visible and the displayed preview uses the selected theme
- **AND** switching theme keeps the new preview recoverable with Fit

### Requirement: Gallery viewport artifact compatibility

Viewport controls SHALL leave qualified source and SVG bytes unchanged. Without
JavaScript, the existing static previews, family links, source panels and
downloads SHALL remain available. Historical release trees SHALL retain their
original artifacts.

#### Scenario: Compare qualified artifacts

- **WHEN** gallery controls are added and the artifact inventory is checked
- **THEN** existing source and static SVG bytes and URLs are unchanged
- **AND** only reviewed current-player HTML and new viewer assets differ

#### Scenario: No-script gallery

- **WHEN** JavaScript is disabled at a narrow viewport
- **THEN** static previews and their existing navigation and downloads work
- **AND** inactive interactive viewport controls are absent

