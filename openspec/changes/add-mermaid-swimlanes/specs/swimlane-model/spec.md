# Spec Delta

## Purpose

Describe responsibility-based swimlane diagrams independently of Mermaid
spelling, layout coordinates or BPMN document types.

## ADDED Requirements

### Requirement: Immutable swimlane values

The diagram library SHALL provide immutable swimlane values for ordered lanes,
nested groups, nodes and connections, with title and accessibility fields.
Construction and transformations SHALL copy caller-owned mutable collections
and SHALL NOT change input values. The model SHALL not depend on Mermaid or
BPMN syntax/document modules.

#### Scenario: A caller changes its input array

- **WHEN** a caller constructs a diagram from an array and then changes that array
- **THEN** the diagram retains its original nodes and order

### Requirement: Lane order and ownership

Lanes SHALL have stable IDs, labels, declared order and optional local direction.
Each node SHALL have at most one effective lane and an ordered containing-group
path. Nodes outside all lanes SHALL remain explicitly unowned. A group inside
a lane SHALL remain a nested group rather than becoming another top-level lane.

#### Scenario: Nested group in a lane

- **WHEN** a lane contains a group with two nodes
- **THEN** both nodes belong to that lane, keep their nested group path and do not create two additional lanes

#### Scenario: Unowned node

- **WHEN** a node appears outside all subgraphs
- **THEN** its lane is absent and the model does not invent an actor name for it

### Requirement: Shape and label information

Nodes SHALL keep their IDs, decoded labels, label kind, standard shape identity,
shape metadata and optional links/render properties. Groups and lanes SHALL
keep their own labels and expanded/collapsed state. Reading a new or asset-dependent shape SHALL not silently
replace its declared identity with a rectangle or a BPMN activity kind.

#### Scenario: Task and decision shapes

- **WHEN** nodes declare a rectangle, rounded rectangle, stadium, diamond and circle
- **THEN** each has its own shape identity in the model

#### Scenario: An asset-dependent node

- **WHEN** a node declares an icon/image shape
- **THEN** its model retains that shape and asset metadata so rendering can report the missing support explicitly

### Requirement: Distinct connection identity and markers

Each connection SHALL keep its source, target, ID, declared order, label and label kind, line
style, minimum-length hint and marker at each end. Parallel connections SHALL
remain distinct. The model SHALL distinguish directed, bidirectional, undirected
and invisible connections without assigning process-execution semantics.

#### Scenario: Parallel handoffs

- **WHEN** two labelled connections join the same two nodes
- **THEN** their IDs, labels, order and individual connection values remain distinct

#### Scenario: Different markers

- **WHEN** source contains a dotted arrow, a thick arrow, an unheaded line and a bidirectional arrow
- **THEN** the model keeps their line styles, endpoint markers and directions separately

### Requirement: Flow and lane directions

The model SHALL keep global flow direction separately from lane/group direction.
It SHALL represent the four effective global directions and the `TD` alias
through conversion. Direction SHALL affect placement and SHALL NOT reverse the
declared source/target identities of a connection.

#### Scenario: Right-to-left flow

- **WHEN** a diagram has `RL` direction and a connection from `A` to `B`
- **THEN** the connection still has source `A` and target `B` even when `B` is placed to the left

### Requirement: Model validation

Validation SHALL detect ambiguous IDs, missing connection endpoints, ownership
cycles, inconsistent group paths and unsupported direction values in
constructed models. It SHALL report stable diagnostics identifying affected
elements and SHALL not repair them by silently moving nodes or changing edges.

#### Scenario: A cycle in group ownership

- **WHEN** a constructed group names its own descendant as its parent
- **THEN** validation reports the ownership cycle without unbounded traversal

#### Scenario: A missing target

- **WHEN** a constructed connection targets an absent node or group
- **THEN** validation identifies that connection and target instead of creating an endpoint during rendering
