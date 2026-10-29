# diagram-viewer-controls Specification

## Purpose

Let readers inspect diagram images and animation stages through consistent,
accessible viewport controls that a host can style.

## Requirements

### Requirement: Corner viewport toolbar

Each enhanced diagram viewport SHALL provide top-right Fullscreen, Zoom in,
Zoom out and Fit buttons. Buttons SHALL have accessible names, visible focus
and targets of at least 44 CSS pixels. The toolbar SHALL stay fixed within
the viewport while the diagram moves.

#### Scenario: Inspect a large diagram

- **WHEN** a reader opens an enhanced viewport at 360 CSS pixels
- **THEN** all four controls are visible and operable without page overflow
- **AND** activating a control does not follow a surrounding gallery link

### Requirement: Bounded zoom and fit

Zoom SHALL enlarge or reduce the displayed diagram without changing its source
or layout. Scale SHALL stay between 25 percent and 800 percent of the fitted
view, with a visible scale value. Fit SHALL show the complete diagram and reset
pan. Limits SHALL disable the corresponding zoom button.

#### Scenario: Zoom and reset

- **WHEN** a reader zooms in, pans, then selects Fit
- **THEN** the complete diagram is visible and the scale reads 100 percent
- **AND** the source, downloads and logical playback position are unchanged

#### Scenario: Repeated zoom at a limit

- **WHEN** a reader reaches either scale limit
- **THEN** scale remains bounded and the corresponding button is disabled

### Requirement: Pointer and keyboard pan

Readers SHALL be able to drag an enlarged diagram with a mouse or a single
touch pointer. A focused viewport SHALL support arrow-key panning. Pan SHALL
keep the diagram recoverable with Fit. Input outside the viewport and input on
controls SHALL retain its normal behavior.

#### Scenario: Pointer and keyboard inspection

- **WHEN** a reader drags an enlarged image and then presses an arrow key while the viewport has focus
- **THEN** both actions move the visible diagram without changing its content
- **AND** releasing or cancelling the pointer ends the drag

#### Scenario: Page and control interaction

- **WHEN** a reader scrolls the page or interacts with a toolbar or playback control
- **THEN** the viewport does not start a drag or intercept unrelated keyboard input

### Requirement: Fullscreen lifecycle and fallback

Fullscreen SHALL show one viewport with its toolbar. Escape or Exit fullscreen
SHALL restore the prior page and return focus to the initiating control. When
native fullscreen is unavailable or rejected, an accessible page overlay SHALL
provide the expanded view and restore page scrolling on close.

#### Scenario: Native fullscreen

- **WHEN** a reader enters fullscreen, zooms, and exits
- **THEN** the toolbar remains usable, the diagram remains visible and focus returns to the initiating button

#### Scenario: Fullscreen is denied

- **WHEN** the browser rejects or does not provide native fullscreen
- **THEN** the viewport opens in a dismissible overlay without an uncaught error
- **AND** keyboard focus stays in the overlay until it closes

### Requirement: Public styling hooks

The shared viewport SHALL document stable root and part classes plus namespaced
CSS custom properties for colors, surfaces, borders, focus, spacing and radii.
A host SHALL be able to override those properties per viewer. Styling overrides
SHALL work inline and in fullscreen without changing control behavior.

#### Scenario: Host overrides one viewer

- **WHEN** a page applies documented accent, surface, spacing and radius overrides to one of two viewers
- **THEN** only that viewer uses the overrides, including in its expanded view
- **AND** both viewers retain keyboard, zoom, pan and fit behavior

### Requirement: Progressive enhancement and isolation

Without JavaScript, the complete static diagram and existing links SHALL remain
usable and inactive viewport buttons SHALL be absent. Viewer state SHALL stay
independent per instance. Printing SHALL show the complete untransformed diagram
without toolbars or transient overlays.

#### Scenario: Multiple viewers and no script

- **WHEN** a reader changes one viewport or opens a page without JavaScript
- **THEN** other viewports remain unchanged, or static diagrams and links remain available without inactive controls

#### Scenario: Print a zoomed diagram

- **WHEN** a reader prints after zooming and panning
- **THEN** print contains the complete static diagram without viewport controls
