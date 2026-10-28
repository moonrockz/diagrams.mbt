# swimlane-svg-rendering Specification

## Purpose

Lay out swimlane models with clear ownership bands and handoff routes, then
paint deterministic, legible standalone SVG using the shared diagram themes.

## Requirements

### Requirement: All documented flow directions

Layout SHALL support `TB`, `TD`, `BT`, `LR` and `RL`, with `TD` equal to `TB`.
Lanes SHALL keep declaration order on the axis across the flow: left-to-right
for vertical flow and top-to-bottom for horizontal flow. Reversing flow SHALL
not reverse lane order or connection identity. Explicit supported local
directions SHALL be retained inside their lane/group.

#### Scenario: Horizontal responsibility bands

- **WHEN** an `LR` diagram declares Customer, Support and Engineering in that order
- **THEN** the output has horizontal lanes in that top-to-bottom order and flow progresses left-to-right

#### Scenario: Reverse vertical flow

- **WHEN** the same lane model uses `BT`
- **THEN** lanes remain in left-to-right declaration order while forward-flow placement progresses bottom-to-top

### Requirement: Lane and group geometry

Layout SHALL keep visible nodes, nested groups and labels inside their effective
lane/group bounds. It SHALL reserve readable lane titles and preserve empty
lanes. Unowned nodes SHALL occupy an unowned region without an invented lane
label. Explicit collapsed groups SHALL show their boundary and label while
keeping hidden descendants outside the visible scene.

#### Scenario: A long lane title

- **WHEN** a lane title is longer than its nodes' labels
- **THEN** layout reserves enough measured header space and handoff edges do not run through its text

#### Scenario: An empty lane and an unowned node

- **WHEN** the model contains an empty declared lane and a node outside all lanes
- **THEN** both remain visible and the unowned node is not assigned to the empty lane

#### Scenario: A handoff crosses a collapsed group boundary

- **WHEN** a visible connection's semantic endpoint is inside a collapsed group
- **THEN** its display route attaches to that group's outline while retaining the original endpoint identity
- **AND** it does not expose hidden internal nodes or invent an internal route

### Requirement: Complete vector shape and line painting

Rendering SHALL support the pinned Mermaid 12.2.0 built-in vector shape catalog,
text/multiline labels, line styles and endpoint markers. It SHALL keep nested
group and lane boundaries distinct. Invisible connections SHALL constrain layout
without being painted. Asset-dependent or unknown shapes SHALL give an error
and no SVG rather than a replacement symbol.

#### Scenario: Native shapes and connections

- **WHEN** the frozen coverage corpus contains each vector shape and marker form
- **THEN** each has a stored geometry/painting assertion and a matching readable SVG snapshot

#### Scenario: Invisible connection

- **WHEN** two nodes are joined by an invisible layout connection
- **THEN** their placement honors the constraint and the output has no visible line or arrow for that connection

#### Scenario: Image shape without support

- **WHEN** the model declares an image node
- **THEN** rendering reports its identity and unsupported asset feature, returns no SVG and performs no fetch

### Requirement: Handoff routing and graph structure

Layout SHALL route connections to the actual node/group/lane outline and retain
labels, direction, markers and distinct parallel connections. It SHALL handle
cycles, self-loops, cross-lane edges, branches, joins and disconnected nodes.
Unconnected nodes SHALL keep source order. Routing SHALL protect unrelated
shapes, labels and lane-title text from intersection.

#### Scenario: Cyclic handoff

- **WHEN** a request crosses three lanes and a rejection returns to an earlier node
- **THEN** routing terminates and shows all forward and return connections with their declared endpoints and labels

#### Scenario: Two edges share endpoints

- **WHEN** two labelled handoffs connect the same nodes
- **THEN** output gives them distinguishable routes or ports and keeps both labels

#### Scenario: Unconnected source order

- **WHEN** a lane declares unconnected nodes `Z`, `A` and `M` in that order
- **THEN** layout does not alphabetically reorder them

### Requirement: Swimlane legibility and explicit layout limits

A public checker SHALL find unintended shape/label/route intersections, label
overflow, ownership/endpoint errors, text below 11 px and contrast below 4.5:1.
Intended containment SHALL not be an overlap error. Layout/checking SHALL obey
explicit node, edge, depth and work limits, with distinct limit findings and no
partial result presented as complete output.

#### Scenario: Corpus legibility

- **WHEN** every supported corpus diagram is laid out and checked in dark and light themes
- **THEN** the checker reports no legibility findings

#### Scenario: Budget exhausted

- **WHEN** a routing search exhausts its configured work limit
- **THEN** rendering reports a layout-limit error and returns no partial SVG

### Requirement: Standalone themed SVG

The existing SVG renderer SHALL accept the swimlane diagram kind and return
`image/svg+xml`. Output SHALL be well-formed, script-free and self-contained,
with title/accessibility description, shared adaptive/fixed theme modes and
escaped identity/link metadata. Explicit ID prefixes SHALL isolate inline
copies. Equal inputs SHALL give identical bytes on all four targets.

#### Scenario: Two inline copies

- **WHEN** two copies have different ID prefixes and theme overrides
- **THEN** each uses its own markers, styles and node identities without affecting the other

#### Scenario: Source markup stays data

- **WHEN** labels or styling/callback metadata contain markup-like text
- **THEN** output contains safe text/metadata and no source-supplied executable markup or CSS

### Requirement: Existing diagram output remains stable

Swimlane support SHALL preserve existing sequence and BPMN static rendering
behavior and SVG bytes for unchanged inputs/options except reviewed connector
changes under the connector-rendering contract. Shared geometry refactoring SHALL
not change their public layout contracts or require a BPMN document module to
render a swimlane model.

#### Scenario: Existing snapshot corpus

- **WHEN** existing sequence/BPMN static corpus tests run after swimlane support is added
- **THEN** their content and semantics remain unchanged on all four targets, with reviewed deterministic updates limited to connector geometry and crossing treatment
