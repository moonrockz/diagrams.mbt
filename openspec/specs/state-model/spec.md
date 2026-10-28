# state-model Specification

## Purpose
Represent state diagrams independently of their source language while retaining
state hierarchy, region ownership and transition identities for all consumers.

## Requirements

### Requirement: Immutable state values

The library SHALL provide immutable ordered states, regions, transitions,
descriptions, notes, direction and accessibility metadata. Construction and
transformations SHALL copy mutable input collections. The model SHALL work
without syntax, renderer, host, BPMN or UI dependencies.

#### Scenario: Change an input array

- **WHEN** a caller changes a state array after model construction
- **THEN** the model retains its original states and order

### Requirement: State hierarchy and concurrent regions

States SHALL distinguish simple and composite forms. Regions SHALL retain
ordered membership, owner state and separator orientation. Each state SHALL
have one owning region. Nested, empty and concurrent regions SHALL remain
explicit without becoming lanes or fabricated transitions.

#### Scenario: Two regions inside a nested state

- **WHEN** a composite state contains two concurrent regions and a nested composite
- **THEN** ownership, region order and nesting remain inspectable without adding connections between their members

### Requirement: Typed pseudostates

The model SHALL distinguish initial, final, choice, fork, join, shallow history,
deep history, entry point and exit point roles. Source-specific boundary symbols
SHALL retain typed identity. Implicit initial and final symbols SHALL have stable
scoped IDs. History SHALL keep its owning scope without resolving a past state.

#### Scenario: Initial symbols in separate regions

- **WHEN** two regions each declare `[*] --> Idle`
- **THEN** each initial symbol and each resolved endpoint has its own source-compatible identity and owning region

#### Scenario: History variants

- **WHEN** a model contains shallow and deep history in one composite
- **THEN** inspection distinguishes both roles and no current or previous state is inferred

### Requirement: Transition identity and descriptive behavior

Transitions SHALL retain IDs, declared endpoints, order, labels, direction,
markers, line styles and source bindings. Parallel transitions and self-loops
SHALL remain distinct. Descriptions, event/guard/action text and entry/do/exit
or internal behavior text SHALL remain ordered data without evaluation. Internal
behavior SHALL NOT create an external transition or invented self-loop.

#### Scenario: Same endpoints and different guards

- **WHEN** two transitions connect the same states with different guard labels
- **THEN** both remain separately identifiable and their guard text is unchanged

#### Scenario: Internal behavior text

- **WHEN** a state description contains an entry action and an internal event line
- **THEN** both lines remain inspectable and no route edge is added for either line

### Requirement: Bounded structural validation

Validation SHALL detect duplicate IDs, missing endpoints or note targets,
ownership cycles, missing owners and invalid region or pseudostate references.
It SHALL validate structural consistency without asserting executable UML
semantics. Explicit size, nesting, diagnostic and work limits SHALL distinguish
invalid input from exhaustion, with no successful complete result on failure.

#### Scenario: Ownership cycle and work limit

- **WHEN** one model has cyclic ownership and another exceeds its validation budget
- **THEN** the first reports invalid ownership and the second reports exhaustion instead of validation success

### Requirement: Portable deterministic state processing

Construction, validation and transformations SHALL be pure and deterministic on
wasm, wasm-gc, js and native. Stable IDs SHALL preserve equal-label states and
source occurrence bindings independently of layout. Direction changes SHALL NOT
reverse semantic transition endpoints.

#### Scenario: Right-to-left layout

- **WHEN** an `A` to `B` transition is laid out right-to-left on each target
- **THEN** all models retain `A` as source and `B` as target with equal identities
