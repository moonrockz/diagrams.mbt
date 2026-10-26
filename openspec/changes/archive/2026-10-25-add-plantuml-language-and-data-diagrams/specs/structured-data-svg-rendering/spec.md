# Spec Delta

## Purpose

Draw structured-data values as readable containers, rows and hierarchy
connections with safe highlights and portable standalone SVG output.

## ADDED Requirements

### Requirement: Ordered data layout

Layout SHALL preserve member order and array positions while measuring keys,
scalar labels, container headers and child connections. Empty containers,
scalar roots and nested mixed collections SHALL remain visible. Large labels
SHALL wrap without changing or silently truncating the value.

#### Scenario: Nested collections and repeated values

- **WHEN** an object contains arrays, empty containers and repeated scalar values
- **THEN** all values appear in order, with separate row identities and correctly attached child connections

### Requirement: Standalone data themes and safe text

Rendering SHALL provide complete, deterministic, script-free SVG using the
shared adaptive and fixed dark/light themes. It SHALL escape keys and values,
preserve scalar distinctions and scope resource IDs by prefix. Titles and
accessibility text SHALL describe the data view. Other diagram kinds' static
SVG bytes SHALL remain unchanged.

#### Scenario: A value contains markup

- **WHEN** a key or value contains SVG, HTML or script-like text
- **THEN** it is displayed as text without active markup, requests or author code

### Requirement: Safe semantic highlights

Resolved highlights SHALL style the selected value or member occurrence under
the library's theme and contrast policy. Unapplied author styles SHALL not
become injected CSS. Highlighting SHALL preserve the value, scalar type,
layout and other occurrence identities.

#### Scenario: Highlight one repeated row

- **WHEN** an occurrence-specific highlight selects one of two equal rows
- **THEN** only that row receives the semantic highlight and both values remain intact

### Requirement: Bounded geometry and legibility

The library SHALL expose deterministic data geometry and a legibility checker
for row bounds, label clearance, child attachment and contrast. Node, depth,
work, width and output bounds SHALL be explicit. Exhaustion SHALL return a
diagnostic without a partial successful SVG.

#### Scenario: Deep data exceeds a limit

- **WHEN** a nested data view exceeds its depth or placement budget
- **THEN** rendering reports limit exhaustion rather than cropping hidden descendants or overflowing the stack

### Requirement: Row and connector scene bindings

Display scenes SHALL bind both visible rows and drawn connectors to stable
semantic identities. A row without a connector SHALL support inspection and
node-visit playback without a fabricated path. Canonical SVG SHALL contain
the complete static data view without viewer state.

#### Scenario: Visit an inline scalar

- **WHEN** an object member is drawn as an inline scalar row
- **THEN** the scene can highlight that row and does not create a zero-length or invisible connection for it
