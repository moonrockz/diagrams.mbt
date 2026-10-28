# Spec Delta

## Purpose

Represent flowcharts independently of their source language, with stable
identities for rendering, inspection and structural playback.

## ADDED Requirements

### Requirement: Immutable flowchart values

The library SHALL provide immutable flowchart values for ordered nodes,
connections, groups, explicit lanes, notes, direction, title and accessibility
fields. Construction and transformations SHALL copy mutable input collections.
The model SHALL be usable without syntax, renderer, BPMN or UI dependencies.

#### Scenario: Caller changes an input collection

- **WHEN** a caller constructs a flowchart and then changes its input node array
- **THEN** the model retains its original nodes and declaration order

### Requirement: Typed control roles and labels

Nodes and connections SHALL keep stable IDs, labels, label kinds, shape
identity and typed control roles. Roles SHALL distinguish actions, decisions,
merges, forks, joins, starts, activity finals, flow finals and connectors.
Structured regions SHALL retain branch, loop and parallel-region membership
and condition text without evaluating it. A generic Mermaid shape SHALL NOT
gain an execution role from its shape alone.

#### Scenario: Two distinct final forms

- **WHEN** PlantUML conversion supplies `stop` and `end` control nodes
- **THEN** the model retains their distinct control roles and symbols

#### Scenario: A generic diamond

- **WHEN** a Mermaid diamond has two outgoing edges
- **THEN** its shape and edge labels remain available without asserting exclusive execution

### Requirement: Stable occurrence identity

Parallel connections and separate equal-label actions SHALL remain distinct.
Generated IDs SHALL be deterministic and collision-free within a diagram and
SHALL retain a binding to source occurrences when available. Connections SHALL
keep declared endpoints, order, labels, line styles, endpoint markers and
layout hints independently of their placement.

#### Scenario: Repeated action text

- **WHEN** a modern activity source has two successive actions named `Read`
- **THEN** they have different node IDs and both are inspectable

#### Scenario: Two labelled edges between the same nodes

- **WHEN** two connections share endpoints and have different labels
- **THEN** their IDs, labels and order remain distinct through rendering and playback

### Requirement: Group and lane ownership

Groups SHALL retain ordered nesting, labels, local directions and expanded
state. Lanes SHALL represent explicit responsibility declarations. Ordinary
groups SHALL NOT become lanes. Nodes SHALL retain validated group membership
and at most one effective lane. Notes SHALL keep their attachment targets and
SHALL NOT create control-flow connections.

#### Scenario: Mermaid top-level subgraphs

- **WHEN** a flowchart has two top-level subgraphs and a nested subgraph
- **THEN** all three remain groups and the model contains no invented lanes

#### Scenario: PlantUML partition and lane

- **WHEN** an activity inside a partition is assigned to an explicit lane
- **THEN** it retains both its partition path and lane identity

### Requirement: Direction and bounded validation

The model SHALL support the four global flow directions and retain local
direction hints without reversing connection identities. Bounded validation
SHALL detect duplicate IDs, missing endpoints or note targets, ownership cycles,
invalid control-region references and invalid options. Invalid models SHALL
produce stable diagnostics rather than silent repairs.

#### Scenario: Ownership cycle

- **WHEN** a group identifies one of its descendants as its parent
- **THEN** validation reports the cycle within the supplied work and depth limits

#### Scenario: Right-to-left flow

- **WHEN** a model uses `RL` and contains a connection from `A` to `B`
- **THEN** the connection still identifies `A` as source and `B` as target

### Requirement: Portable flowchart processing

Model construction, validation and transformations SHALL be pure and
deterministic on wasm, wasm-gc, js and native. Processing SHALL obey explicit
node, connection, nesting and work limits. Limit exhaustion SHALL be distinct
from invalid input and SHALL NOT produce a successful complete result.

#### Scenario: Validation budget exhausted

- **WHEN** validation consumes its supplied work budget
- **THEN** it returns a limit diagnostic rather than claiming that validation passed
