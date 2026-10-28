# Spec Delta

## MODIFIED Requirements

### Requirement: Supplied geometry policy

Layout SHALL support prefer-supplied, require-supplied and automatic policies.
Complete valid supplied geometry SHALL retain shape, label and waypoint
coordinates. Supplied paths SHALL remain unstyled by default. Prefer-supplied SHALL use a complete automatic layout with a warning
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
equal geometry on all four targets, without an external layout service. Automatic connections SHALL follow the
shared connector style, crossing and marker-clearance contract.

#### Scenario: A cyclic process

- **WHEN** a process branches through a gateway and one branch returns to an earlier task
- **THEN** layout terminates and routes both branches and the return edge with their labels and arrowheads

#### Scenario: Multiple lanes and messages

- **WHEN** two pools contain nested lanes, long task labels and cross-pool message flows
- **THEN** each node stays in its lane and each message reaches its declared pool or activity endpoint

#### Scenario: Short final approach

- **WHEN** an automatic BPMN return flow would turn too close to its arrowhead
- **THEN** its route reserves the required straight marker approach in every direction without changing the endpoint

### Requirement: Preserve existing sequence output

Adding BPMN support SHALL preserve existing sequence model behavior and SVG bytes
for equal existing inputs and options except reviewed connector changes under
the connector-rendering contract. The public API change from adding a BPMN
diagram variant SHALL be documented for callers with exhaustive matches.

#### Scenario: Existing sequence snapshots

- **WHEN** the existing sequence corpus is rendered with its existing options after BPMN support is added
- **THEN** all sequence content and semantics remain unchanged, with deterministic reviewed updates limited to connector geometry and crossing treatment on all four targets

## ADDED Requirements

### Requirement: Explicit display styling of supplied paths

The renderer SHALL allow explicit connector styling of supplied BPMN paths.
Source waypoints, shape bounds, semantic endpoints and the source document
SHALL remain unchanged. Display geometry SHALL expose the styled path and the
original points separately. Unsafe requested styling SHALL give a diagnostic
without silently moving the supplied geometry.

#### Scenario: Explicitly style supplied paths

- **WHEN** a caller opts into curved lines or crossing bridges for a complete supplied plane
- **THEN** display paths use the requested styling, source waypoints and shape bounds remain unchanged, and inspection retains the supplied points
- **AND** an unsafe styled path gives a diagnostic without silently moving supplied shapes or waypoints
