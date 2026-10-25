# Spec Delta

## Purpose

Convert BPMN process and collaboration views to immutable diagram values and
render them as legible, deterministic standalone SVG.

## ADDED Requirements

### Requirement: Explicit BPMN view selection

Conversion SHALL select a process, collaboration or diagram interchange plane by
identity. Automatic selection SHALL consider planes first, collaborations second
and processes last, using the first nonempty tier. It SHALL select only one
candidate; multiple candidates SHALL give an ambiguity diagnostic and no diagram.
Selecting choreography or conversation SHALL give an unsupported-view diagnostic
without changing the source document.

#### Scenario: A document has two process views

- **WHEN** conversion receives two eligible processes without a view selection
- **THEN** it reports their identities and returns no diagram

#### Scenario: Select one plane

- **WHEN** the caller selects a plane by its diagram ID
- **THEN** conversion uses that plane and its referenced process or collaboration

#### Scenario: One collaboration contains two processes

- **WHEN** a document has no planes, one collaboration and two participant processes
- **THEN** automatic conversion selects the collaboration with both participant processes

#### Scenario: One plane refers to one process

- **WHEN** a document has one plane and its referenced process
- **THEN** automatic conversion selects the plane without treating its referenced process as a competing view

#### Scenario: Choreography rendering is deferred

- **WHEN** the caller selects a valid choreography view
- **THEN** conversion reports that view as unsupported and its source remains available for writing and traversal

### Requirement: Immutable BPMN diagram model

The diagram library SHALL provide a BPMN model that keeps element identities,
kinds, containment, flow endpoints, labels, optional links, render properties
and selected view geometry. It SHALL distinguish sequence flows, message flows,
associations and data associations. Constructing or converting a diagram SHALL
not change the BPMN document or any input model.

#### Scenario: Preserve flow kinds

- **WHEN** a collaboration has a sequence flow inside one pool and a message flow between two pools
- **THEN** the diagram keeps both flow kinds, their IDs and their correct endpoints

### Requirement: Process and collaboration coverage

Conversion and rendering SHALL cover BPMN 2.0.2 process/collaboration graphical
elements: activities and markers, events and event definitions, gateways,
subprocesses, pools, nested lanes, flow kinds, data elements, groups and text
annotations. Every selected graphical element SHALL be drawn or identified in
an error diagnostic. It SHALL NOT be silently omitted or shown as another kind.

#### Scenario: Recognizable BPMN symbols

- **WHEN** a process has a start event, user task, exclusive gateway and end event
- **THEN** output uses the event circles, user-task marker, gateway diamond and end-event border defined by BPMN

#### Scenario: Event and activity markers

- **WHEN** corpus views contain interrupting and non-interrupting boundary events, event subprocesses, call activities and loop/multi-instance markers
- **THEN** snapshots keep each element's standard border, attachment and markers

#### Scenario: A closed participant

- **WHEN** a collaboration participant has no visible process
- **THEN** the output contains its labelled black-box pool and message connections without inventing internal activities

### Requirement: Supplied geometry policy

Layout SHALL support prefer-supplied, require-supplied and automatic policies.
Complete valid supplied geometry SHALL retain shape, label and waypoint
coordinates. Prefer-supplied SHALL use a complete automatic layout with a warning
when geometry is absent or incomplete. Invalid supplied geometry SHALL give an
error under supplied policies. Require-supplied SHALL fail when geometry is missing.

#### Scenario: Supplied waypoints are preserved

- **WHEN** the selected plane contains complete valid bounds and a four-point edge route
- **THEN** prefer-supplied and require-supplied keep those bounds and route, apart from a documented common viewport translation

#### Scenario: Only some shapes have bounds

- **WHEN** the plane omits one required shape bound under prefer-supplied
- **THEN** layout warns and computes the whole selected view automatically without mixing coordinate systems

#### Scenario: A negative shape width

- **WHEN** supplied geometry contains a negative shape width under require-supplied
- **THEN** rendering returns a geometry error and no SVG

### Requirement: Deterministic automatic layout

Automatic layout SHALL size labels by measured text and keep pools, lanes,
subprocesses and attached events in their proper containment. It SHALL route
connections to their actual endpoints and handle cycles, branches, joins,
disconnected components and multiple edges. Equal inputs and options SHALL give
equal geometry on all four targets, without an external layout service.

#### Scenario: A cyclic process

- **WHEN** a process branches through a gateway and one branch returns to an earlier task
- **THEN** layout terminates and routes both branches and the return edge with their labels and arrowheads

#### Scenario: Multiple lanes and messages

- **WHEN** two pools contain nested lanes, long task labels and cross-pool message flows
- **THEN** each node stays in its lane and each message reaches its declared pool or activity endpoint

### Requirement: BPMN legibility findings

A public legibility check SHALL find unintended shape/label overlaps, label
overflow, misplaced boundary events, invalid edge endpoints and text below
11 px or 4.5:1 contrast. Intentional containment and attachments SHALL be
excluded from overlap findings. Supplied geometry SHALL be checked without
being silently rearranged. Rendering SHALL return its legibility findings.

#### Scenario: Check an imported layout

- **WHEN** supplied geometry puts a task label over an unrelated gateway
- **THEN** the check reports the conflicting identities and rendering keeps the supplied geometry

#### Scenario: Check an automatic layout

- **WHEN** the checker runs on every automatically laid out corpus view in dark and light themes
- **THEN** it reports no legibility findings

### Requirement: Static standalone BPMN SVG

The SVG renderer SHALL return BPMN output with media type `image/svg+xml` through
the existing renderer contract. The SVG SHALL be well-formed XML, script-free
and self-contained, with title and accessibility description. It SHALL contain
no external resources or active vendor markup. Equal inputs SHALL produce
identical bytes on all four targets.

#### Scenario: Standalone output

- **WHEN** each supported BPMN corpus view is rendered
- **THEN** its SVG contains all required local definitions and no script, external resource or foreign extension markup copied from the source

#### Scenario: Error output

- **WHEN** the selected view has an ambiguous flow endpoint
- **THEN** the renderer returns a diagnostic and no output rather than an apparently complete SVG

### Requirement: Theme and source identity

BPMN rendering SHALL use the existing adaptive and fixed theme policies and
archify classic colour tokens while retaining BPMN notation. Output SHALL give
shapes and connections distinct stable identities and escaped source-ID/link
metadata. Caller-supplied ID prefixes SHALL isolate multiple inline diagrams.

#### Scenario: Two copies in one page

- **WHEN** two copies of one BPMN view use different ID prefixes and theme overrides
- **THEN** each copy resolves its own markers and colours without affecting the other

#### Scenario: A source ID is markup-like text

- **WHEN** an element name or extension value contains markup-like text
- **THEN** rendered text and metadata are escaped and do not become executable markup

### Requirement: Preserve existing sequence output

Adding BPMN support SHALL preserve existing sequence model behavior and SVG bytes
for equal existing inputs and options. The public API change from adding a BPMN
diagram variant SHALL be documented for callers with exhaustive matches.

#### Scenario: Existing sequence snapshots

- **WHEN** the existing sequence corpus is rendered with its existing options after BPMN support is added
- **THEN** all stored sequence SVG snapshots remain byte-identical on all four targets
