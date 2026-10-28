# Spec Delta

## ADDED Requirements

### Requirement: Player raster downloads

The shared offline player SHALL offer canonical PNG and JPEG downloads and
animated GIF export through the diagram-raster-export contract. PNG SHALL be
the default still format. The export controls SHALL have public styling hooks
and preserve the existing canonical SVG download.

#### Scenario: Save a still or animation

- **WHEN** a reader selects PNG, JPEG or animated GIF
- **THEN** export uses the selected format and validated options with accessible feedback
- **AND** the live player's position, speed, route, zoom and pan remain unchanged

### Requirement: Themed player presentation

The shared offline player SHALL use the site's Smithy-aligned light and dark
palette with an explicit system option. It SHALL provide a clear heading,
prominent diagram stage, primary playback action, timeline with position and
duration, and grouped exploration controls. Fixed-theme diagram colors SHALL
remain independent from the surrounding player theme.

#### Scenario: Open a player in either theme

- **WHEN** a reader opens a player in light, dark or system mode
- **THEN** its controls, surfaces, focus states and timeline use the selected shell palette
- **AND** the SVG remains readable in its supplied fixed or adaptive theme

#### Scenario: Narrow player layout

- **WHEN** a reader opens a player at 360 CSS pixels
- **THEN** the diagram, playback, position, speed, scope and exploration controls remain usable without horizontal page overflow

### Requirement: Player theme preference

When opened from the site, a player SHALL honor the site's stored theme
preference when storage is available. Standalone use or blocked storage SHALL
fall back to the system preference. A host's explicit viewer theme SHALL take
precedence over stored and system preferences.

#### Scenario: Site preference and blocked storage

- **WHEN** the site has a stored dark preference or the browser blocks storage
- **THEN** the player uses dark or falls back to the system without a script error
- **AND** an explicit host theme overrides either result

### Requirement: Player viewport controls

The animation stage SHALL follow the diagram-viewer-controls contract. Zoom,
pan, fit and fullscreen SHALL move the complete diagram and its transient
overlays together. Viewport actions SHALL preserve position, speed, occurrence,
selected route and playback state.

#### Scenario: Inspect during playback

- **WHEN** a reader zooms, pans or enters fullscreen during playback
- **THEN** highlighted connections and tokens remain aligned with the diagram
- **AND** viewport actions do not restart or seek the animation

#### Scenario: Download while enlarged

- **WHEN** a reader downloads SVG after zooming and selecting a route
- **THEN** the download equals canonical static rendering
- **AND** no viewport transform, UI control or transient overlay appears in the download

### Requirement: Player styling contract

The shared player SHALL document stable root and part hooks for its header,
stage, playback bar, timeline, status and exploration panel. Hosts SHALL be able
to override namespaced CSS custom properties per viewer for palette, typography,
spacing and radii without editing the runtime or losing accessible controls.

#### Scenario: Custom player skin

- **WHEN** a host applies documented palette, font, spacing and radius hooks
- **THEN** the player and viewport toolbar use those values inline and expanded
- **AND** playback, seeking, keyboard use and exploration still work

### Requirement: Player presentation compatibility

Player presentation changes SHALL retain offline use, safe label encoding,
equal output bytes on all four targets, reduced-motion behavior and inactive-page
handling. Printing SHALL show the complete static diagram. The default SHALL
remain paused and semantic scope text SHALL remain visible.

#### Scenario: Offline and reduced motion

- **WHEN** a player opens with network blocked and reduced motion enabled
- **THEN** the themed controls and explicit stepping work with no remote request
- **AND** no continuous animation starts

#### Scenario: Existing family regression

- **WHEN** existing player suites run after the presentation change
- **THEN** all diagram families retain motion bindings, route bounds, scope labels, safe hostile labels and canonical downloads

