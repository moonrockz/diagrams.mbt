# flowchart-svg-rendering Specification

## Purpose
Lay out flowchart models and draw readable standalone SVG with shared themes,
stable geometry and bindings for inspection and playback.

## Requirements

### Requirement: Deterministic graph layout

Layout SHALL support all four flow directions, local group directions,
disconnected nodes, cycles, self-loops, branches, joins and parallel edges.
It SHALL retain identities and source order for otherwise unconstrained
elements. Connections SHALL attach to actual endpoint outlines, keep their
markers and labels and avoid unrelated shapes and text.

#### Scenario: Parallel edges and a cycle

- **WHEN** a graph has two labelled edges from `A` to `B`, a self-loop and an edge back from `B`
- **THEN** each edge has its own selectable path and readable label, and layout terminates in every global direction

### Requirement: Group and explicit lane geometry

Layout SHALL retain nested group containment, group headings and explicit lane
ownership without adding lane bands to ordinary Mermaid subgraphs. Empty
groups and lanes SHALL remain visible. Collapsed groups SHALL hide descendant
geometry and attach crossing display routes to their boundary while keeping
semantic endpoints. Effective local direction SHALL follow the source profile.

#### Scenario: Mermaid groups without lanes

- **WHEN** a Mermaid flowchart has two subgraphs
- **THEN** SVG shows two group boundaries without responsibility bands

#### Scenario: Crossing a collapsed group

- **WHEN** a visible edge targets a hidden descendant of a collapsed group
- **THEN** its display path attaches to the group outline and no hidden interior geometry is drawn

### Requirement: Complete supported vector painting

Rendering SHALL draw the pinned Mermaid built-in vector shape catalog and
supported PlantUML action, control, connector and note symbols. It SHALL retain
line styles, endpoint markers, multiline text and branch labels. Invisible
connections SHALL affect layout without being painted. Unknown or
asset-dependent symbols SHALL give errors and no SVG rather than replacement
rectangles or external fetches.

#### Scenario: Shape and control coverage

- **WHEN** the coverage corpus is rendered
- **THEN** every supported vector shape, final form, fork/join, note and marker has geometry assertions and a readable snapshot

#### Scenario: Unsupported image

- **WHEN** a model contains a remote image shape
- **THEN** rendering identifies the unsupported symbol and returns no SVG without a request

### Requirement: Public geometry and legibility checks

The library SHALL expose deterministic geometry and a bounded checker for
containment, endpoint attachment, label fit, unintended shape/label/route
intersections, text below 11 px and contrast below 4.5:1. Intended containment
and declared group-boundary attachment SHALL NOT be overlap errors. All
supported corpus examples SHALL pass in fixed light and dark themes.

#### Scenario: Long labels in nested groups

- **WHEN** the checker receives geometry for long multiline labels and nested groups
- **THEN** it reports actual overflow and unintended intersections while accepting correct containment

### Requirement: Standalone themed flowchart SVG

The shared SVG renderer SHALL accept the flowchart kind and return
`image/svg+xml`. Output SHALL be well-formed, script-free, self-contained and
deterministic on all four targets, with adaptive and fixed themes, title and
accessibility description. Text, links and metadata SHALL follow the shared
escaping and link policy. Caller ID prefixes SHALL isolate inline copies.

#### Scenario: Inline copies and source markup

- **WHEN** two copies use different prefixes and labels containing markup-like text
- **THEN** markers and styles remain isolated and labels render as text without source-supplied active markup

### Requirement: Flowchart scene bindings

Scenes SHALL bind visible nodes, groups, lanes, notes and connections to stable
model identities. Each playable connection SHALL bind to its real drawn path.
Semantic and display endpoints SHALL remain separate at collapsed boundaries.
Isolated visible nodes SHALL support inspection and node visits without a
fabricated connection. Canonical static SVG SHALL exclude player state.

#### Scenario: Isolated action

- **WHEN** a visible action has no connection
- **THEN** it has an inspectable scene binding and can receive a timed node visit without an invisible path

### Requirement: Explicit layout limits and existing output stability

Layout, checking and SVG writing SHALL obey explicit node, edge, depth, work,
dimension and output limits. Exhaustion SHALL return a distinct diagnostic
without partial successful output. Existing diagram models and public layout
contracts SHALL remain unchanged. Static SVG bytes SHALL remain unchanged except
reviewed connector changes under the connector-rendering contract.

#### Scenario: Routing budget exhausted

- **WHEN** routing consumes its supplied work budget
- **THEN** rendering returns a layout-limit error and no partial SVG

#### Scenario: Existing static corpus

- **WHEN** existing sequence, BPMN, swimlane, architecture, railroad and data-tree snapshots run
- **THEN** their content and semantics remain unchanged on all four targets, with reviewed deterministic updates limited to connector geometry and crossing treatment
