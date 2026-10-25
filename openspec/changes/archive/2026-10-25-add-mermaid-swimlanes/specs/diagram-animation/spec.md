# Spec Delta

## ADDED Requirements

### Requirement: Swimlane motion catalog and bindings

The shared animation API SHALL accept swimlane diagrams and retain node/group,
lane and connection identities in its catalog and scene bindings. Each visible
connection occurrence SHALL bind to its actual rendered path. Parallel edges
SHALL remain independently selectable. Invisible layout constraints SHALL be
excluded from playback and route graphs.

#### Scenario: Animate a cross-lane handoff

- **WHEN** a caller plays a connection from Customer to Support
- **THEN** motion follows that connection's routed path between the actual endpoint outlines

#### Scenario: Select one parallel edge

- **WHEN** two labelled handoffs connect the same endpoints and one ID is selected
- **THEN** only that connection's occurrence is highlighted or played

#### Scenario: Invisible edge

- **WHEN** an invisible connection is present in the layout model
- **THEN** it creates no playable occurrence or route through the animation graph

### Requirement: Swimlane route direction

Swimlane routes SHALL follow directed arrow semantics, support both directions
of bidirectional connections and obey explicit reverse queries. Unheaded
connections SHALL participate only when undirected exploration is explicitly
enabled. A resolved route SHALL retain each connection's traversal direction,
and playback SHALL follow that direction without changing its markers.

#### Scenario: Right-to-left layout is not a reversed edge

- **WHEN** an `RL` diagram contains `A --> B` and the reader selects `A` then `B`
- **THEN** a forward route exists and its motion follows `A` to `B` even though it travels left

#### Scenario: Bidirectional return

- **WHEN** a bidirectional connection joins `A` and `B` and the route starts at `B`
- **THEN** playback travels from `B` to `A` along the same connection with its markers intact

#### Scenario: Unheaded connector is opt-in

- **WHEN** `A --- B` is the only connection and undirected exploration is disabled
- **THEN** directed route search reports no route
- **AND** enabling undirected exploration permits either traversal direction without claiming a directed business flow

### Requirement: Swimlane scope and structural exploration

Swimlane route/reachability queries SHALL keep the existing deterministic bounds
and result distinctions. They SHALL use explicit connections, not lane
membership or position. Collapsed group descendants SHALL be outside the visible
query scope. Route output SHALL remain structural and SHALL not evaluate labels
as conditions or reinterpret a diamond as a BPMN gateway.

#### Scenario: A shared lane is not an edge

- **WHEN** two nodes share one lane but have no connecting path
- **THEN** route search reports them as disconnected

#### Scenario: Collapsed group

- **WHEN** a requested endpoint is hidden inside a collapsed group
- **THEN** the query reports it outside the current view rather than inventing a route through that group

### Requirement: Shared standalone playback for swimlanes

The animated renderer SHALL provide the existing offline playback, route/reach,
keyboard, reduced-motion, visibility and static-export behavior for swimlanes.
Export SHALL give the canonical static swimlane SVG without transient overlays.
Existing sequence/BPMN playback behavior SHALL remain unchanged; shared-runtime
byte changes SHALL be covered by updated deterministic HTML snapshots.

#### Scenario: Export while playing

- **WHEN** a selected swimlane route is playing and the reader downloads SVG
- **THEN** the download equals the direct static render and the viewer keeps its playback position and selection

#### Scenario: Existing diagram playback

- **WHEN** existing sequence and BPMN browser qualification runs with the extended runtime
- **THEN** playback controls, route semantics, safe labels and canonical static downloads still pass their contracts
