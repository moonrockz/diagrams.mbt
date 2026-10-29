# diagram-raster-export Specification

## Purpose

Let callers and gallery readers save diagrams.mbt-generated SVG as raster
images, and export source-bound diagram playback as animated GIF.

## Requirements

### Requirement: Built-in raster conversion

The library SHALL provide a supported public API that converts diagrams.mbt
SVG output to PNG or JPEG bytes without a browser, external executable or remote
service. It SHALL support wasm, wasm-gc, JavaScript and native targets.
PNG SHALL be the default still format. Existing text renderer APIs SHALL remain
compatible.

#### Scenario: Convert outside the site

- **WHEN** a standalone consumer supplies generated SVG and valid PNG or JPEG options on any supported target
- **THEN** the API returns decodable image bytes, the correct media type and dimensions
- **AND** the consumer needs no gallery, UI framework or external conversion tool

### Requirement: Generated SVG coverage

Raster conversion SHALL preserve complete content from every implemented diagram
family, including labels, supplied fonts, icons, colors, curves, arrowheads,
clipping and connector crossing masks. Adaptive SVG SHALL resolve to an explicit
export theme. Unsupported input or unavailable required glyphs SHALL produce
diagnostics without silently dropping content.

#### Scenario: Render labels and crossed connectors

- **WHEN** a generated diagram with text, icons, curved connectors and crossing masks is rasterized
- **THEN** labels and icons remain readable, arrowheads are present and crossing separation remains visible

#### Scenario: Theme and unsupported content

- **WHEN** a caller supplies an adaptive generated SVG with an explicit theme, or supplies unsupported content
- **THEN** output uses that theme or returns a source-specific diagnostic without a partial success result

### Requirement: Raster sizing and format options

Callers SHALL be able to choose output dimensions or scale while preserving
aspect ratio, background color and export theme. PNG SHALL support alpha.
JPEG SHALL composite onto an explicit opaque background and accept a validated
quality value. Result metadata SHALL identify the actual format and dimensions.

#### Scenario: Transparent PNG and opaque JPEG

- **WHEN** a caller exports the same SVG to transparent PNG and JPEG with a chosen background
- **THEN** PNG retains requested transparency and JPEG composites onto the chosen background
- **AND** both use the requested dimensions without cropping the diagram

### Requirement: Animated GIF export

The library SHALL encode a multi-frame GIF from a validated playback plan and
diagram scene. Options SHALL select a bounded interval, dimensions, frame rate,
background and loop behavior. Sampling SHALL use logical time, retain repeated
and concurrent occurrences, and preserve connector paths and masks.
GIF palette and timing limitations SHALL be documented.

#### Scenario: Export a finite scenario

- **WHEN** a caller exports a finite plan with repeated and concurrent steps
- **THEN** a decoded GIF contains multiple timed frames that show those occurrences in order
- **AND** the requested interval includes the correct first and final views

#### Scenario: Export an illustrative cycle

- **WHEN** a caller exports one explicit bounded interval of a repeating illustration
- **THEN** the result has the requested loop setting and a finite frame count
- **AND** it does not record an unbounded wall-clock session

### Requirement: Deterministic binary results

Equal source, font inputs, options and playback samples SHALL produce equal
raster bytes on all four targets. Results SHALL carry binary data, media type,
dimensions and diagnostics. Encoding failure SHALL return no success payload.
Conversion SHALL NOT mutate SVG source, source models or playback plans.

#### Scenario: Compare targets and inputs

- **WHEN** one fixture is converted on all supported targets
- **THEN** encoded bytes and metadata match and input digests remain unchanged

### Requirement: Bounded raster work

The API SHALL validate dimensions, scale, quality, interval, frame rate and loop
options before allocation. Limits SHALL bound pixels, frames, cumulative frame
work and encoded output bytes with overflow-safe arithmetic. Invalid input,
malformed SVG or exhausted limits SHALL return diagnostics rather than partial
downloads or unbounded work.

#### Scenario: Reject an excessive animation

- **WHEN** requested dimensions and frame count exceed a configured budget
- **THEN** export fails with an identified limit and no success payload

#### Scenario: Reject an invalid option

- **WHEN** a dimension, scale, quality, interval or frame rate is invalid
- **THEN** export returns a diagnostic before unsafe allocation or frame generation

### Requirement: Shared download conversion path

Gallery and player raster downloads SHALL use the supported library conversion
path. Still downloads SHALL convert canonical SVG and exclude viewport state
and transient highlights. Animated GIF SHALL use the selected playback plan
and explicit export interval. Original SVG downloads SHALL remain available.

#### Scenario: Download after viewport changes

- **WHEN** a reader zooms, pans and downloads PNG or JPEG
- **THEN** the file contains the complete canonical diagram without toolbar or viewport cropping
- **AND** its decoded pixels match the library conversion for the same options

#### Scenario: Preserve playback during GIF export

- **WHEN** a reader exports GIF from a paused or playing scenario
- **THEN** the file contains the requested animation rather than a screenshot
- **AND** export does not restart, seek or change the live player's route or speed

### Requirement: Responsive export feedback

Interactive exports SHALL show format, dimensions and progress or busy state.
Readers SHALL be able to cancel an animation export. Invalid options and
conversion failures SHALL leave source and SVG actions usable and show an
accessible explanation. Export SHALL work offline with supplied local assets.

#### Scenario: Cancel or fail a download

- **WHEN** a reader cancels GIF export or conversion fails
- **THEN** no partial file is offered, the interface becomes usable and live playback state is retained

#### Scenario: Export offline

- **WHEN** the generated local gallery or standalone player exports with network access blocked
- **THEN** PNG, JPEG and available GIF export use only supplied local assets
