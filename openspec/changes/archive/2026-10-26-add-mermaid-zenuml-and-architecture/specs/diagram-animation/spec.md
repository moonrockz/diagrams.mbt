# Spec delta

## ADDED Requirements

### Requirement: Architecture catalog and scene bindings

The animation API SHALL accept architecture diagrams and retain service,
junction, group and connection identities. Each connection occurrence SHALL
bind to its actual rendered path. Parallel edges SHALL remain selectable
independently. Group-boundary attachment SHALL not replace authored service
endpoints with group IDs in the route graph.

#### Scenario: Connection between grouped services

- **WHEN** playback selects an edge attached to the groups beside two services
- **THEN** motion follows the rendered group-boundary path while the catalog retains the two service identities

### Requirement: Architecture direction and structural queries

Architecture route and reachability queries SHALL follow arrowhead direction.
Bidirectional edges SHALL permit both directions; unheaded edges SHALL require
explicit undirected exploration. Results SHALL retain traversal direction.
Junctions SHALL be graph endpoints; containment, alignment and proximity SHALL
not create edges. Queries SHALL retain existing deterministic bounds and result
distinctions.

#### Scenario: Bidirectional return route

- **WHEN** a route traverses a bidirectional edge in the reverse of its stored endpoint order
- **THEN** playback follows the resolved traversal direction with the original markers intact

#### Scenario: Unheaded edge

- **WHEN** two services have only an unheaded edge and undirected exploration is disabled
- **THEN** directed search reports no route
- **AND** enabling undirected exploration permits traversal in either direction

#### Scenario: Aligned services have no connection

- **WHEN** services share a group and alignment but no connecting path
- **THEN** reachability reports them as disconnected

### Requirement: Shared standalone architecture playback

Architecture HTML SHALL provide existing offline playback, explicit scenarios,
route/reachability controls, keyboard access, reduced-motion, visibility and
static-export behavior. It SHALL start still. Playback SHALL describe authored
connections without asserting execution or deployment outcomes. Equal inputs
SHALL produce identical HTML bytes on all four targets.

#### Scenario: Open architecture playback offline

- **WHEN** an architecture artifact opens with network requests blocked
- **THEN** symbols, controls and routes work without network requests or console errors

#### Scenario: Canonical export during playback

- **WHEN** a reader downloads SVG while an architecture route is playing
- **THEN** it equals a direct static render and the player retains selection and logical playback position

### Requirement: ZenUML sequence projection and exception scenarios

Converted ZenUML SHALL use the shared sequence catalog, occurrence ordering and
scene bindings. Explicit scenarios SHALL identify selected exception sections
and retain finally as a distinct role. Unselected sections SHALL remain visible
without playback. The player SHALL not evaluate exceptions or infer which
section executes from labels.

#### Scenario: Explicit catch and finally selection

- **WHEN** a caller supplies a scenario selecting one catch section and a finally section
- **THEN** playback follows those selected occurrences in supplied order without selecting another catch or claiming an exception was evaluated

### Requirement: Existing playback and new symbols remain intact

Extending shared playback SHALL preserve sequence/BPMN/swimlane behavior.
Annotated participant symbols SHALL remain in canonical/display SVG, still
states, print output and static download. Shared HTML byte changes SHALL remain
deterministic and satisfy the existing browser contracts.

#### Scenario: Annotated sequence export

- **WHEN** an annotated ZenUML sequence is paused, stepped, printed and exported
- **THEN** its symbols remain present and downloaded SVG equals the direct static output

#### Scenario: Existing player qualification

- **WHEN** existing sequence, BPMN and swimlane browser suites run with the extended runtime
- **THEN** controls, route semantics, safe labels and canonical downloads continue to pass
